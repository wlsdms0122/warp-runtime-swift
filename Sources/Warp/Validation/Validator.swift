//
//  Validator.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Checks that every name a procedure reads is one it can see, before it runs.
//
// The walk is structural, and it stays structural through call: a message
// carries expressions whose insides this can read, so what exists inside a
// caller's body is read here rather than asked of whatever answers the
// selector. Which means validation never consults the word table. A document is
// checked against itself, before anything is resolved.
public struct Validator: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // The door for a caller holding statements it assembled itself, without a
    // document: the same gate the load path passes, against the heads visible
    // where the body will run.
    public func validate(body: [Statement], visible: Set<Name>) throws {
        try validate(body, visible: visible, at: .given("lowered"))
    }

    // A single expression, checked where a caller is about to evaluate one it
    // assembled itself.
    public func validate(_ expression: Expression, visible: Set<Name>) throws {
        try validate(expression, visible: visible, at: .given("expression"))
    }

    // Every declaration a module makes, in name order so the first refusal is
    // stable across runs. Nothing about the module as a whole is checked here.
    // Whether its names collide with another module's is a link question, and
    // there is no other module in sight from inside one.
    public func validate(_ module: Module) throws {
        let constants = Set(module.constants.keys)
        let variables = Set(module.variables.keys)

        // A constant sees no scope, so it may name another constant and nothing
        // else. Which is also why it is checked here rather than per procedure:
        // what it can see is a fact about the module.
        for (name, expression) in module.constants.sorted(by: { $0.key < $1.key }) {
            try validate(
                expression,
                visible: constants,
                surroundings: .procedure(constants: constants),
                at: .constant(name.spelling, in: .of(module))
            )
        }

        // A variable's start is written like a constant and sees what a
        // constant sees: the constants beside it, and no variable. A variable
        // holds nothing until the run starts.
        for (name, expression) in module.variables.sorted(by: { $0.key < $1.key }) {
            guard !constants.contains(name) else {
                throw ValidationError(
                    "'\(name)' is declared as a constant and as a variable, and"
                        + " one name holds one thing",
                    at: .variable(name.spelling, in: .of(module))
                )
            }

            try validate(
                expression,
                visible: constants,
                surroundings: .procedure(constants: constants),
                at: .variable(name.spelling, in: .of(module))
            )
        }

        // A declared type's name is a record's name in every encoding, so it
        // is held to the one grammar those encodings write bare.
        for name in module.types.keys.sorted() where !name.isDeclarable {
            throw ValidationError(
                "'\(name)' is not a type's name. A type is named by identifiers joined by dots",
                at: .type(name.spelling, in: .of(module))
            )
        }

        for name in module.procedures.keys.sorted() {
            guard let procedure = module.procedures[name] else { continue }

            try validate(
                procedure,
                constants: constants,
                variables: variables,
                at: .procedure(name.spelling, in: .of(module))
            )
        }

        // Last, because it is the least specific thing that can be wrong: a
        // module whose bodies do not even check is refused for that, and going
        // first would make the list the only thing an author ever heard about.
        try declared(module)
    }

    // A parameter is a name the body can read, so it is visible from the first
    // statement, and declared, so a statement cannot introduce it again. The
    // body and the signature are one scope, and a name is introduced once in a
    // scope.
    public func validate(
        _ procedure: Procedure,
        constants: Set<Name> = [],
        variables: Set<Name> = []
    ) throws {
        try validate(procedure, constants: constants, variables: variables, at: .given("procedure"))
    }

    // MARK: - Private
    // What a module says it imports against what it sends. A caller reads the
    // list to decide whether to grant the words before it links anything, so a
    // list allowed to drift would be worse than none: it would be trusted and
    // wrong.
    private func declared(_ module: Module) throws {
        let sends = module.sends

        guard sends != module.imports else { return }

        // The two differences and not the two lists. They are different
        // mistakes with different fixes (a word sent and not listed is the
        // grant the list existed to disclose, and a word listed and not sent
        // asks for one the program has no use for) and a module sending thirty
        // words would otherwise leave an author diffing two of them by eye to
        // find the one that moved.
        let undisclosed = sends.subtracting(module.imports).sorted().map(\.spelling)
        let unspent = module.imports.subtracting(sends).sorted().map(\.spelling)

        let said = [
            undisclosed.isEmpty ? nil : "sends \(undisclosed), which it does not import",
            unspent.isEmpty ? nil : "imports \(unspent), which it does not call"
        ]

        throw ValidationError(
            said.compactMap { said in said }.joined(separator: ", and "),
            at: Place([.slot(.imports)], in: .of(module))
        )
    }

    // One parameter, and everything a parameter is held to. Two walks meet a
    // signature (a procedure's and a closure's) and a rule written at one of
    // them is a rule the other does not have.
    private func validate(
        _ parameter: Name,
        of signature: Signature,
        beside constants: Set<Name>,
        at here: Place
    ) throws {
        try introduced(parameter, beside: constants, at: here)

        // A default is a value a document writes, so it is held to what a
        // document can hold. It reaches the wire without ever passing through
        // a body, so a body's rules never see it.
        guard let fallback = signature.parameters[parameter]?.default else { return }

        guard !fallback.holdsProcedure else {
            throw ValidationError(Value.procedureIsNotData, at: here)
        }

    }

    private func validate(
        _ procedure: Procedure,
        constants: Set<Name>,
        variables: Set<Name>,
        at place: Place
    ) throws {
        let parameters = Set(procedure.signature.parameters.keys)
        let bound = constants.union(variables)

        for parameter in parameters.sorted() {
            try validate(
                parameter,
                of: procedure.signature,
                beside: bound,
                at: place.slot(.parameters).key(parameter.spelling)
            )
        }

        guard let block = procedure.block else { return }

        // A parameter handed in place is a variable in the body: the box is
        // the caller's, and writing it is what the parameter is for.
        let handed = parameters.filter { name in
            procedure.signature.parameters[name]?.declared.isInout == true
        }

        try validate(
            block,
            visible: bound.union(parameters),
            variables: variables.subtracting(parameters).union(handed),
            declared: parameters,
            surroundings: .procedure(constants: bound),
            at: place
        )
    }

    // What the body leaves behind for what follows it: the names it made
    // visible, and which of them are variables. A result written after the body
    // sees both.
    @discardableResult
    private func validate(
        _ body: [Statement],
        visible startVisible: Set<Name>,
        variables startVariables: Set<Name> = [],
        declared startDeclared: Set<Name> = [],
        surroundings: Surroundings = .procedure,
        at place: Place
    ) throws -> (visible: Set<Name>, variables: Set<Name>) {
        var visible = startVisible
        var variables = startVariables
        var declared = startDeclared

        for (position, statement) in body.enumerated() {
            // A statement is its name and the construct it writes under. Both,
            // because a document writes both and following one word at a time
            // is what a place is for.
            let here = place.statement(statement, at: position)

            if let binding = statement.binding {
                if statement.expression.alwaysLeaves {
                    throw ValidationError(
                        "every way through this statement"
                            + " leaves, so its name could never bind. It takes"
                            + " no name",
                        at: here
                    )
                }

                if statement.expression.answersNothing {
                    throw ValidationError(
                        "a conditional answers nothing, so its name"
                            + " could never bind. It takes no name",
                        at: here
                    )
                }

                switch binding {
                case let .constant(name, _), let .variable(name, _):
                    try introduced(name, beside: surroundings.constants, at: here)

                    guard !declared.contains(name) else {
                        throw ValidationError("duplicate statement id '\(name)'", at: here)
                    }

                    declared.insert(name)

                // A write names a path, and the head of the path is the
                // variable it writes. The rest of the path is judged at the
                // link, where the variable's shape is known.
                case let .assignment(path):
                    if let refusal = path.markedHead {
                        throw ValidationError(refusal, at: here)
                    }

                    guard let head = path.head else {
                        throw ValidationError(
                            "writes a path headed by no name. A write starts at a variable",
                            at: here
                        )
                    }

                    guard variables.contains(head) else {
                        let reason = if visible.contains(head) {
                            "which is a fixed name here. Declare it as a variable to write it"
                        } else {
                            "which is not visible here. Declare it earlier or check the spelling"
                        }

                        throw ValidationError("assigns '\(head)', \(reason)", at: here)
                    }
                }
            }

            if statement.expression.alwaysLeaves, position != body.count - 1 {
                throw ValidationError(
                    "every way through this"
                        + " statement leaves, and what follows it here"
                        + " would never run",
                    at: here
                )
            }

            try validate(
                statement.expression,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: here
            )

            switch statement.binding {
            case let .constant(id, _)?:
                visible.insert(id)
                variables.remove(id)

            case let .variable(id, _)?:
                visible.insert(id)
                variables.insert(id)

            case .assignment?, nil:
                break
            }
        }

        return (visible, variables)
    }

    private func validate(
        _ expression: Expression,
        visible: Set<Name>,
        variables: Set<Name> = [],
        surroundings: Surroundings = .procedure,
        at place: Place
    ) throws {
        switch expression {
        // A literal is data. One shape a value has is not data (a closure is
        // made by running the expression that writes one) so a program carrying
        // one as a literal is carrying something no text spells and nothing
        // reads back. A caller assembling shapes in Swift is the only one that
        // can build it, and this is the door it comes through.
        case let .literal(value):
            guard !value.holdsProcedure else {
                throw ValidationError(Value.procedureIsNotData, at: place)
            }

        case let .reference(path):
            try validate(paths: path.expandingIndexReferences, visible: visible, at: place)

        case let .array(array):
            for (position, element) in array.enumerated() {
                let here = place.index(position)

                try refuseAnswerless(element, at: here)
                try validate(element, visible: visible, variables: variables, surroundings: surroundings, at: here)
            }

        case let .record(record):
            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                try refuseAnswerless(field, at: place.key(name.spelling))
                try validate(
                    field,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: place.key(name.spelling)
                )
            }

        // A cast names a shape and reads a value as it. The shape is the link's
        // to resolve, so the check has only the value to walk, exactly as it
        // walks any other operand.
        case let .cast(value, _, _):
            try refuseAnswerless(value, at: place.slot(.receiver))
            try validate(
                value,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.receiver)
            )

        // A closure sees where it was written plus what it declares, which is
        // the capture read statically. Its parameters are declared here for the
        // same reason a procedure's are: the signature and the body are one
        // scope.
        //
        // Variables are not carried in. A closure may outlive the block that
        // made it, so writing an enclosing box through one would be a write
        // with no bounded lifetime. A name it captured is a value it captured.
        // Where a leave may go. A closure is a procedure of its own, so the
        // loops around where it was *written* are not around where it runs.
        // `rounds` starts empty inside one, and reaching for an outer loop from
        // there is refused here rather than discovered at a run.
        case let .leave(leave):
            try validate(leave, in: surroundings, at: place)

            // What a `return` carries is an operand like any other. A name it
            // reads has to be visible where it was written, and a construct
            // that answers nothing has nothing to hand back. Only `return`
            // reaches here with one: the check above refuses a value on the two
            // that end a loop.
            guard let value = leave.value else { return }

            try refuseAnswerless(value, at: place)
            try validate(
                value,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place
            )

        case let .closure(procedure):
            let inside = place.slot(.closure)
            let parameters = Set(procedure.signature.parameters.keys)

            // The same rule the top-level signature gets. A closure's parameter
            // is a name a body reads, wherever the signature sits.
            for parameter in parameters.sorted() {
                try validate(
                    parameter,
                    of: procedure.signature,
                    beside: surroundings.constants,
                    at: inside.slot(.parameters).key(parameter.spelling)
                )
            }

            guard let block = procedure.block else { return }

            try validate(
                block,
                visible: visible.union(parameters),
                variables: variables.subtracting(parameters),
                declared: parameters,
                surroundings: surroundings.enclosed,
                at: inside
            )

        case let .apply(callee, arguments):
            try refuseConstruct(callee, at: place.slot(.callee))
            try validate(
                callee,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.callee)
            )

            for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                let here = place.argument(name.spelling)

                try refuseConstruct(argument, at: here)
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: here
                )
            }

        case let .block(block):
            try validate(block, visible: visible, variables: variables, surroundings: surroundings, at: place)

        case let .conditional(condition, then, otherwise):
            try refuseConstructCondition(
                condition,
                at: place.slot(.condition(of: .conditional))
            )
            try validate(
                condition,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.condition(of: .conditional))
            )
            try validate(
                then,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.then)
            )

            if let otherwise {
                try validate(
                    otherwise,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: place.slot(.otherwise)
                )
            }

        // The round state is bound before the condition is asked, which is what
        // lets `while` read how many rounds have passed.
        case let .loop(condition, body, round):
            try introduced(round, beside: surroundings.constants, at: place)

            let inner = visible.union([round])

            try refuseConstructCondition(condition, at: place.slot(.condition(of: .loop)))
            try validate(
                condition,
                visible: inner,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.condition(of: .loop))
            )
            try validate(
                body,
                visible: inner,
                variables: variables,
                surroundings: surroundings.inside(round),
                at: place
            )

        // While the rescue runs, the failure is a value under the declared name.
        case let .attempt(block, rescue, failure):
            try introduced(failure, beside: surroundings.constants, at: place)

            try validate(
                block,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place
            )

            guard !rescue.body.isEmpty || rescue.result != nil else {
                // An empty rescue would swallow a failure into null without a
                // trace. If the alternate path produces nothing, the author's
                // honest form is no rescue at all.
                throw ValidationError("must not be empty", at: place.slot(.rescue))
            }

            try validate(
                rescue,
                visible: visible.union([failure]),
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.rescue)
            )

        case let .call(call):
            if let receiver = call.receiver {
                try refuseConstruct(receiver, at: place.slot(.receiver))
                try validate(
                    receiver,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: place.slot(.receiver)
                )
            }

            for (name, argument) in call.arguments.sorted(by: { $0.key < $1.key }) {
                let here = place.argument(name.spelling)

                try refuseConstruct(argument, at: here)
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: here
                )
            }

        }
    }

    // A construct that answers nothing (a conditional) has nothing to give a
    // slot that exists to hold an answer. Refused for that reason wherever one
    // asks, rather than as a null that fails to fit downstream.
    private func refuseAnswerless(_ expression: Expression, at place: Place) throws {
        guard expression.answersNothing else { return }

        throw ValidationError(
            "this construct answers nothing, so it cannot"
                + " stand where a value is wanted",
            at: place
        )
    }

    // A call's operand is data the pure half reads. A document cannot even
    // write a construct there, and the run refuses one that arrives anyway.
    // Held here too, so a program assembled directly meets the same rule before
    // it runs, and at the link, which asks the same predicate, so a program
    // that skipped this door still cannot slip one through: the body a word is
    // to run travels as a closure, and there is no second channel for bodies.
    private func refuseConstruct(_ expression: Expression, at place: Place) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError(Expression.constructInOperand, at: place)
    }

    // A condition is data by the same fact an operand is: the run asks it
    // purely. Refused with its own sentence, because the fix is different. What
    // a body decides reaches a condition through a word.
    private func refuseConstructCondition(_ expression: Expression, at place: Place) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError(Expression.constructInCondition, at: place)
    }

    private func validate(
        _ block: Block,
        visible: Set<Name>,
        variables: Set<Name> = [],
        declared: Set<Name> = [],
        surroundings: Surroundings = .procedure,
        at place: Place
    ) throws {
        let inner = try validate(
            block.body,
            visible: visible,
            variables: variables,
            declared: declared,
            surroundings: surroundings,
            at: place.slot(.body)
        )

        if let result = block.result {
            // The result runs after the body, so it is "after" the same way a
            // trailing statement is. A body that left never reaches it.
            if block.body.alwaysLeaves {
                throw ValidationError(
                    "nothing runs after leaving,"
                        + " and this result would never be reached",
                    at: place.slot(.result)
                )
            }

            // A conditional answers nothing, so a result slot (a place that
            // exists to hold an answer) has nothing to take from one. Refused
            // for that reason, rather than as a type that fails to fit
            // downstream.
            try refuseAnswerless(result, at: place.slot(.result))

            try validate(
                result,
                visible: inner.visible,
                variables: inner.variables,
                surroundings: surroundings,
                at: place.slot(.result)
            )
        }
    }

    // What a leave may say, and where it may say it.
    private func validate(
        _ leave: Leave,
        in surroundings: Surroundings,
        at place: Place
    ) throws {
        guard leave.reach != .procedure else {
            guard leave.target == nil else {
                throw ValidationError(
                    "answering leaves the procedure it is written in,"
                        + " and names no other",
                    at: place
                )
            }

            return
        }

        guard leave.value == nil else {
            throw ValidationError(
                "a loop answers what it was going to answer,"
                    + " so ending one carries nothing",
                at: place
            )
        }

        guard let nearest = surroundings.rounds.last else {
            throw ValidationError("there is no loop here to leave", at: place)
        }

        guard let target = leave.target else { return }

        guard surroundings.rounds.contains(target) else {
            throw ValidationError(
                "names '\(target)', which is not a loop around it."
                    + " The ones here are \(surroundings.rounds.reversed().map(\.spelling).joined(separator: ", "));"
                    + " the nearest is '\(nearest)'",
                at: place
            )
        }
    }

    private func validate(
        paths: [[PathSegment]],
        visible: Set<Name>,
        at place: Place
    ) throws {
        for path in paths {
            if let refusal = path.markedHead {
                throw ValidationError(refusal, at: place)
            }

            guard let head = path.head else {
                throw ValidationError(
                    "reference { ref: \(path.rendered) } does not"
                        + " start with a name",
                    at: place
                )
            }

            guard visible.contains(head) else {
                throw ValidationError(
                    "reference { ref: \(path.rendered) } names"
                        + " '\(head)', which is not visible here. Declare it earlier"
                        + " or check the spelling",
                    at: place
                )
            }
        }
    }

    // A name a body introduces: a parameter, a statement's id, or the one a
    // construct hands its body. Every such name passes here, so the module's
    // bound names are checked at whatever depth the name appears. A sub scope
    // is where a reader is least able to see that the spelling was taken.
    //
    // Linking folds a constant wherever its name is read, so a name introduced
    // under that spelling would never be the one that answers.
    private func introduced(
        _ name: Name,
        beside constants: Set<Name>,
        at place: Place
    ) throws {
        guard constants.contains(name) else { return }

        throw ValidationError(
            "'\(name)' collides with a name the module bound, which it would"
                + " take the place of",
            at: place
        )
    }
}

// Where a body is, as far as leaving it is concerned.
//
// One value rather than a parameter each: a body checked without its loops
// reads as a body outside any loop, so carrying the whole is the default and
// every place that breaks it has to say so.
private struct Surroundings: Sendable {
    // MARK: - Property
    // The loops around here, nearest last. A name reaches past the nearer ones,
    // and nothing here means there is no loop to end.
    let rounds: [Name]

    // The module's bound names, carried so every signature met on the way (a
    // closure's included) refuses a parameter that would take one's place:
    // linking folds a constant wherever its name is read, so a parameter under
    // that name would never be the one that answers.
    let constants: Set<Name>

    // A procedure's own body: no loop yet.
    static let procedure = Surroundings(rounds: [], constants: [])

    static func procedure(constants: Set<Name>) -> Surroundings {
        Surroundings(rounds: [], constants: constants)
    }

    // MARK: - Public
    func inside(_ round: Name) -> Surroundings {
        Surroundings(rounds: rounds + [round], constants: constants)
    }

    // A procedure written inside another. It may be called anywhere and long
    // after, so the loops around where it was *written* are not around where it
    // runs, and its own answer is its own. What it captured it may write: a
    // variable's box is one thing under one name everywhere the name is
    // visible, and this body is one of those places.
    var enclosed: Surroundings {
        Surroundings(rounds: [], constants: constants)
    }

    // MARK: - Private
}

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
// selector. Which means validation never consults the procedure table. A document is
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
    public func validate(body: Body, visible: Set<Name>) throws {
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
                scope: .procedure(constants: constants),
                at: .constant(name.spelling, in: .of(module))
            )
        }

        // A variable's start is written like a constant and sees what a
        // constant sees: the constants beside it, and no variable. A variable
        // holds nothing until the run starts.
        for (name, variable) in module.variables.sorted(by: { $0.key < $1.key }) {
            guard !constants.contains(name) else {
                throw ValidationError(
                    "'\(name)' is declared as a constant and as a variable, and"
                        + " one name holds one thing",
                    at: .variable(name.spelling, in: .of(module))
                )
            }

            try validate(
                variable.start,
                visible: constants,
                scope: .procedure(constants: constants),
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

        // A claim is about a declared type. A value of a type the language
        // names wears no name a run could read, so no declaration could answer
        // a contract for it.
        for name in module.claims.keys.sorted() where TypeExpression.keywords[name] != nil {
            throw ValidationError(
                "'\(name)' is a type the language names, and a claim is about a declared type",
                at: .satisfies(name.spelling, in: .of(module))
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
    // What a module says it imports against what it uses: the procedures it
    // sends and the types, constraints and contracts it names. A caller reads
    // the list to decide what to grant and what to lay in the link before it
    // links anything, so a list allowed to drift would be worse than none: it
    // would be trusted and wrong.
    private func declared(_ module: Module) throws {
        let used = Set(module.references.map(\.name))

        let undisclosed = used.subtracting(module.imports).sorted().map(\.spelling)
        let unspent = module.imports
            .filter { name in !used.contains(name) }
            .sorted()
            .map(\.spelling)

        guard !undisclosed.isEmpty || !unspent.isEmpty else { return }

        // The two differences and not the two lists. They are different
        // mistakes with different fixes (a name used and not listed is the
        // dependency the list existed to disclose, and a name listed and not
        // used asks for one the program has no use for) and a module using
        // thirty names would otherwise leave an author diffing two of them by
        // eye to find the one that moved.
        let said = [
            undisclosed.isEmpty ? nil : "uses \(undisclosed), which it does not import",
            unspent.isEmpty ? nil : "imports \(unspent), which it does not use"
        ]

        throw ValidationError(
            said.compactMap { said in said }.joined(separator: ", and "),
            at: Place([.part(.imports)], in: .of(module))
        )
    }

    private func validate(
        _ procedure: Procedure,
        constants: Set<Name>,
        variables: Set<Name>,
        at place: Place
    ) throws {
        let parameters = Set(procedure.signature.names)
        let bound = constants.union(variables)

        for (position, parameter) in procedure.signature.names.enumerated() {
            try introduced(parameter, beside: bound, at: place.part(.parameters).index(position))
        }

        try reads(procedure, at: place)
        try sends(procedure, at: place)

        guard let block = procedure.block else { return }

        // A parameter handed in place is a variable in the body: the box is
        // the caller's, and writing it is what the parameter is for.
        let handed = parameters.filter { name in
            procedure.signature.parameter(named: name)?.declared.isInout == true
        }

        try validate(
            block,
            visible: bound.union(parameters),
            variables: variables.subtracting(parameters).union(handed),
            declared: parameters,
            scope: .procedure(constants: bound),
            at: place
        )
    }

    // A native procedure reads its arguments at the places its own keys stand at,
    // and the row a run hands it is the declaration's parameters in order. The
    // two are the same list or the procedure reads an argument nobody sent it.
    private func reads(_ procedure: Procedure, at place: Place) throws {
        guard let keys = procedure.implementation.nativeParameters else { return }

        let declared = procedure.signature.names
        let read = keys.sorted { left, right in left.position < right.position }

        guard
            read.map(\.position) == Array(declared.indices),
            read.map(\.name) == declared
        else {
            throw ValidationError(
                "this procedure reads \(read.map(\.name.spelling)) and is declared"
                    + " with \(declared.map(\.spelling)). A procedure reads its"
                    + " arguments at the places its own keys stand at",
                at: place.part(.parameters)
            )
        }
    }

    // A native procedure sends the procedures it declares, at the places it names them
    // at, and a run reaches one by that place. The places are one procedure to a
    // place from the first or a place a procedure names reaches nothing.
    private func sends(_ procedure: Procedure, at place: Place) throws {
        guard let keys = procedure.implementation.nativeImports else { return }

        let sent = keys.sorted { left, right in left.position < right.position }

        guard sent.map(\.position) == Array(sent.indices) else {
            throw ValidationError(
                "this procedure sends procedures standing at \(sent.map(\.position)), which is"
                    + " not one procedure to a place from the first",
                at: place.part(.imports)
            )
        }
    }

    // What the body leaves behind for what follows it: the names it made
    // visible, and which of them are variables. A result written after the body
    // sees both.
    @discardableResult
    private func validate(
        _ body: Body,
        visible startVisible: Set<Name>,
        variables startVariables: Set<Name> = [],
        declared startDeclared: Set<Name> = [],
        scope: Scope = .procedure,
        at place: Place
    ) throws -> (visible: Set<Name>, variables: Set<Name>) {
        var visible = startVisible
        var variables = startVariables
        var declared = startDeclared

        for (position, statement) in body.statements.enumerated() {
            // A statement is its name and the construct it writes under. Both,
            // because a document writes both and following one at a time is
            // what a place is for.
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
                    try introduced(name, beside: scope.constants, at: here)

                    guard !declared.contains(name) else {
                        throw ValidationError("duplicate statement id '\(name)'", at: here)
                    }

                    declared.insert(name)

                // A write names a path, and the head of the path is the
                // variable it writes. The rest of the path is judged at the
                // link, where the variable's type is known.
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

            if statement.expression.alwaysLeaves, position != body.statements.count - 1 {
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
                scope: scope,
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
        scope: Scope = .procedure,
        at place: Place
    ) throws {
        switch expression {
        // A literal is data. One kind a value has is not data (a closure is
        // made by running the expression that writes one) so a program carrying
        // one as a literal is carrying something no text spells and nothing
        // reads back. A caller assembling a program in Swift is the only one that
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
                try validate(element, visible: visible, variables: variables, scope: scope, at: here)
            }

        case let .record(record):
            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                let here = place.part(.fields).key(name.spelling)

                try refuseAnswerless(field, at: here)
                try validate(field, visible: visible, variables: variables, scope: scope, at: here)
            }

        // A cast names a type and reads a value as it. The type is the link's
        // to resolve, so the check has only the value to walk, exactly as it
        // walks any other operand.
        case let .cast(value, _, optional):
            try refuseAnswerless(value, at: place.part(.subject(optional: optional)))
            try validate(
                value,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.part(.subject(optional: optional))
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
            try validate(leave, in: scope, at: place)

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
                scope: scope,
                at: place
            )

        case let .closure(procedure):
            let inside = place.part(.closure)
            let parameters = Set(procedure.signature.names)

            // The same rule the top-level signature gets. A closure's parameter
            // is a name a body reads, wherever the signature sits.
            for (position, parameter) in procedure.signature.names.enumerated() {
                try introduced(parameter, beside: scope.constants, at: inside.part(.parameters).index(position))
            }

            try reads(procedure, at: place)

        guard let block = procedure.block else { return }

            try validate(
                block,
                visible: visible.union(parameters),
                variables: variables.subtracting(parameters),
                declared: parameters,
                scope: scope.enclosed,
                at: inside
            )

        case let .apply(callee, arguments):
            try refuseConstruct(callee, at: place.part(.callee))
            try validate(
                callee,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.part(.callee)
            )

            for (position, argument) in arguments.enumerated() {
                let here = place.part(.arguments).index(position)

                try refuseConstruct(argument, at: here)
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    scope: scope,
                    at: here
                )
            }

        case let .block(block):
            try validate(block, visible: visible, variables: variables, scope: scope, at: place)

        case let .conditional(condition, then, otherwise):
            try refuseConstructCondition(
                condition,
                at: place.part(.condition(of: .conditional))
            )
            try validate(
                condition,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.part(.condition(of: .conditional))
            )
            try validate(
                then,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.part(.then)
            )

            if let otherwise {
                try validate(
                    otherwise,
                    visible: visible,
                    variables: variables,
                    scope: scope,
                    at: place.part(.otherwise)
                )
            }

        // The round state is bound before the condition is asked, which is what
        // lets `while` read how many rounds have passed.
        case let .loop(condition, body, round):
            if let round {
                try introduced(round, beside: scope.constants, at: place)
            }

            let inner = visible.union(round.map { round in [round] } ?? [])

            try refuseConstructCondition(condition, at: place.part(.condition(of: .loop)))
            try validate(
                condition,
                visible: inner,
                variables: variables,
                scope: scope,
                at: place.part(.condition(of: .loop))
            )
            try validate(
                body,
                visible: inner,
                variables: variables,
                scope: scope.inside(round),
                at: place
            )

        // While the rescue runs, the failure is a value under the declared name.
        case let .attempt(block, rescue, failure):
            if let failure {
                try introduced(failure, beside: scope.constants, at: place)
            }

            try validate(
                block,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place
            )

            guard !rescue.body.statements.isEmpty || rescue.result != nil else {
                // An empty rescue would swallow a failure into null without a
                // trace. If the alternate path produces nothing, the author's
                // honest form is no rescue at all.
                throw ValidationError("must not be empty", at: place.part(.rescue))
            }

            try validate(
                rescue,
                visible: visible.union(failure.map { failure in [failure] } ?? []),
                variables: variables,
                scope: scope,
                at: place.part(.rescue)
            )

        case let .call(call):
            for (position, argument) in call.arguments.enumerated() {
                let here = place.argument(position)

                try refuseConstruct(argument, at: here)
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    scope: scope,
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

    // A call's operand is data the run reads rather than runs, so it holds no construct.
    private func refuseConstruct(_ expression: Expression, at place: Place) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError(Expression.constructInOperand, at: place)
    }

    // A condition is data by the same fact, refused with its own sentence because the fix differs.
    private func refuseConstructCondition(_ expression: Expression, at place: Place) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError(Expression.constructInCondition, at: place)
    }

    private func validate(
        _ block: Block,
        visible: Set<Name>,
        variables: Set<Name> = [],
        declared: Set<Name> = [],
        scope: Scope = .procedure,
        at place: Place
    ) throws {
        let inner = try validate(
            block.body,
            visible: visible,
            variables: variables,
            declared: declared,
            scope: scope,
            at: place.part(.body)
        )

        if let result = block.result {
            // The result runs after the body, so it is "after" the same way a
            // trailing statement is. A body that left never reaches it.
            if block.body.alwaysLeaves {
                throw ValidationError(
                    "nothing runs after leaving,"
                        + " and this result would never be reached",
                    at: place.part(.result)
                )
            }

            // A conditional answers nothing, so a result slot (a place that
            // exists to hold an answer) has nothing to take from one. Refused
            // for that reason, rather than as a type that fails to fit
            // downstream.
            try refuseAnswerless(result, at: place.part(.result))

            try validate(
                result,
                visible: inner.visible,
                variables: inner.variables,
                scope: scope,
                at: place.part(.result)
            )
        }
    }

    // What a leave may say, and where it may say it.
    private func validate(
        _ leave: Leave,
        in scope: Scope,
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

        guard let nearest = scope.rounds.last else {
            throw ValidationError("there is no loop here to leave", at: place)
        }

        guard let target = leave.target else { return }

        guard scope.rounds.contains(target) else {
            throw ValidationError(
                "names '\(target)', which is not a loop around it."
                    + " The ones here are \(scope.rounds.reversed().map { round in round?.spelling ?? "a nameless one" }.joined(separator: ", "));"
                    + " the nearest is \(nearest.map { nearest in "'\(nearest)'" } ?? "nameless")",
                at: place
            )
        }
    }

    private func validate(
        paths: [Path],
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

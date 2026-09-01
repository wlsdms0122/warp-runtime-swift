//
//  Validator.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Checks that every name a procedure reads is one it can see, before it runs.
//
// The walk is structural, and it stays structural through dispatch: a message
// carries expressions whose insides this can read, so what exists inside a
// caller's body is read here rather than asked of whatever answers the selector.
// Which means validation never consults the word table — a document is
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
    public func validate(body: [Statement], visible: Set<String>) throws {
        try validate(body, visible: visible, at: .given("lowered"))
    }

    // A single expression, checked where a caller is about to evaluate one it
    // assembled itself.
    public func validate(_ expression: Expression, visible: Set<String>) throws {
        try validate(expression, visible: visible, at: .given("expression"))
    }

    // Every declaration a module makes, in name order so the first refusal is
    // stable across runs. Nothing about the module as a whole is checked here —
    // whether its names collide with another module's is a link question, and
    // there is no other module in sight from inside one.
    public func validate(_ module: Module) throws {
        // The namespace a module declares into is a name, and every other name
        // a document writes is held to the same two rules here. A module that
        // writes the key and nothing in it has said it has a namespace and
        // named none — and a name nobody can type is a name no other document
        // can join, which is what a namespace is for.
        if let name = module.name {
            let here = Place([.slot(.name)], in: .of(module))

            guard !name.isEmpty else {
                throw ValidationError("a module that writes a name writes one", at: here)
            }

            try normal(name, at: here)
        }

        let constants = Set(module.constants.keys)

        // A constant sees no scope, so it may name another constant and nothing
        // else. Which is also why it is checked here rather than per procedure:
        // what it can see is a fact about the module.
        for (name, expression) in module.constants.sorted(by: { $0.key < $1.key }) {
            try normal(name, at: .constant(name, in: .of(module)))
            try validate(
                expression,
                visible: constants,
                surroundings: .procedure(constants: constants),
                at: .constant(name, in: .of(module))
            )
        }

        for name in module.procedures.keys.sorted() {
            try normal(name, at: .procedure(name, in: .of(module)))
        }

        for name in module.procedures.keys.sorted() {
            guard let procedure = module.procedures[name] else { continue }

            try validate(procedure, constants: constants, at: .procedure(name, in: .of(module)))
        }

        // Last, because it is the least specific thing that can be wrong: a
        // module whose bodies do not even check is refused for that, and going
        // first would make the list the only thing an author ever heard about.
        try declared(module)
    }

    // A parameter is a name the body can read, so it is visible from the first
    // statement — and declared, so a statement cannot introduce it again. The
    // body and the signature are one scope, and a name is introduced once in a
    // scope.
    public func validate(_ procedure: Procedure, constants: Set<String> = []) throws {
        try validate(procedure, constants: constants, at: .given("procedure"))
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
        // mistakes with different fixes — a word sent and not listed is the
        // grant the list existed to disclose, and a word listed and not sent
        // asks for one the program has no use for — and a module sending
        // thirty words would otherwise leave an author diffing two of them by
        // eye to find the one that moved.
        let undisclosed = sends.subtracting(module.imports).sorted()
        let unspent = module.imports.subtracting(sends).sorted()

        let said = [
            undisclosed.isEmpty ? nil : "sends \(undisclosed), which it does not import",
            unspent.isEmpty ? nil : "imports \(unspent), which it does not send"
        ]

        throw ValidationError(
            said.compactMap { said in said }.joined(separator: ", and "),
            at: Place([.slot(.imports)], in: .of(module))
        )
    }

    private func validate(_ procedure: Procedure, constants: Set<String>, at place: Place) throws {
        let parameters = Set(procedure.signature.parameters.keys)

        for parameter in parameters.sorted() {
            try introduced(
                parameter,
                beside: constants,
                at: place.slot(.parameters).key(parameter)
            )
        }

        guard let block = procedure.block else { return }

        try validate(
            block,
            visible: constants.union(parameters),
            declared: parameters,
            surroundings: .procedure(constants: constants),
            at: place
        )
    }

    @discardableResult
    private func validate(
        _ body: [Statement],
        visible startVisible: Set<String>,
        variables startVariables: Set<String> = [],
        declared startDeclared: Set<String> = [],
        surroundings: Surroundings = .procedure,
        at place: Place
    ) throws -> Set<String> {
        var visible = startVisible
        var variables = startVariables
        var declared = startDeclared

        for (position, statement) in body.enumerated() {
            // A statement is its name and the construct it writes under —
            // both, because a document writes both and following one word at a
            // time is what a place is for.
            let here = place.statement(statement, at: position)

            // A binding with no name is a write that goes nowhere. The document
            // reader cannot produce one — the binding comes from the naming key
            // — so this guards the caller that builds statements directly.
            if statement.id == nil, statement.binding != .constant {
                throw ValidationError(
                    "writes no name, and a \(statement.binding)"
                        + " is a statement about its name",
                    at: here
                )
            }

            if let id = statement.id {
                guard !id.isEmpty else {
                    throw ValidationError("statement with empty id", at: here)
                }

                // An assignment names a name rather than introducing one, so
                // what it may write is the assignment rule's to answer below.
                if case .assignment = statement.binding {
                    try normal(id, at: here)
                } else {
                    try introduced(id, beside: surroundings.constants, at: here)
                }

                // The leave rules reach through structure, because the fact
                // does: every way through a leaving statement leaves, so its
                // name could never bind — refused before any question about
                // which name it is.
                if statement.expression.alwaysLeaves {
                    throw ValidationError(
                        "every way through this statement"
                            + " leaves, so its name could never bind — it takes"
                            + " no name",
                        at: here
                    )
                }

                // A walk answers nothing, so a `var` or `set` on one is a write
                // whose value could only ever be null. The plain name stands
                // for the element inside the body, and that is all it is.
                if statement.binding != .constant, isIteration(statement.expression) {
                    throw ValidationError(
                        "a walk answers nothing, so its name"
                            + " binds the element and no value — it is not"
                            + " writable",
                        at: here
                    )
                }

                // A branch answers nothing and binds nothing inside either, so
                // it takes no name at all: what an arm keeps it writes to an
                // outer variable, and a value leaves through `return`.
                if statement.expression.takesNoName {
                    throw ValidationError(
                        "a branch answers nothing, so its name"
                            + " could never bind — it takes no name",
                        at: here
                    )
                }

                // An assignment is checked before the expression, because what
                // it may write is a fact about the name and not about the value.
                if case .assignment = statement.binding {
                    guard variables.contains(id) else {
                        // The most specific truth wins: a name that is visible
                        // but unwritable across a boundary is refused for the
                        // boundary, not for its binding.
                        let reason = if visible.contains(id), let boundary = surroundings.boundary {
                            boundary
                        } else if visible.contains(id) {
                            "which is a fixed name here — declare it as a variable to write it"
                        } else {
                            "which is not visible here — declare it earlier or check the spelling"
                        }

                        throw ValidationError(
                            "assigns '\(id)', \(reason)",
                            at: here
                        )
                    }
                }

                // Sub scopes restart declaration tracking, so an inner statement
                // may introduce a name an outer body also has — that is
                // shadowing, and it is a different name. Only same-level
                // duplicates are ambiguous.
                if case .assignment = statement.binding {} else {
                    guard !declared.contains(id) else {
                        throw ValidationError("duplicate statement id '\(id)'", at: here)
                    }

                    declared.insert(id)
                }
            }

            // Nothing runs after a statement that leaves — through structure
            // too: a branch both of whose arms leave never finishes either.
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

            switch (statement.binding, statement.id) {
            // A walk answers nothing, so its name is the element's — alive
            // inside the body as `item` and `index`, and nothing afterwards.
            // Leaving it visible would let what follows read a name whose only
            // value could ever be null, silently.
            case (.constant, _?) where isIteration(statement.expression):
                break

            case let (.constant, id?):
                visible.insert(id)
                variables.remove(id)

            case let (.variable, id?):
                visible.insert(id)
                variables.insert(id)

            default:
                break
            }
        }

        return visible
    }

    private func isIteration(_ expression: Expression) -> Bool {
        guard case .iteration = expression else { return false }

        return true
    }

    private func validate(
        _ expression: Expression,
        visible: Set<String>,
        variables: Set<String> = [],
        surroundings: Surroundings = .procedure,
        at place: Place
    ) throws {
        switch expression {
        case .literal:
            return

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
                try refuseAnswerless(field, at: place.key(name))
                try validate(
                    field,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: place.key(name)
                )
            }

        // A cast names a shape and reads a value as it — the shape is the
        // link's to resolve, so the check has only the value to walk, exactly
        // as it walks any other operand.
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
        // made it, so writing an enclosing box through one would be a write with
        // no bounded lifetime — a name it captured is a value it captured.
        // Where a leave may go. A closure is a procedure of its own, so the
        // loops around where it was *written* are not around where it runs —
        // `rounds` starts empty inside one, and reaching for an outer loop from
        // there is refused here rather than discovered at a run.
        case let .leave(leave):
            try validate(leave, in: surroundings, at: place)

            // What a `return` carries is an operand like any other — a name it
            // reads has to be visible where it was written, and a construct
            // that answers nothing has nothing to hand back. Only `return`
            // reaches here with one: the check above refuses a value on the
            // two that end a loop.
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

            // The same rule the top-level signature gets — a closure's
            // parameter is a name a body reads, wherever the signature sits.
            for parameter in parameters.sorted() {
                try introduced(
                    parameter,
                    beside: surroundings.constants,
                    at: inside.slot(.parameters).key(parameter)
                )
            }

            guard let block = procedure.block else { return }

            try validate(
                block,
                visible: visible.union(parameters),
                declared: parameters,
                surroundings: surroundings.enclosed,
                at: inside
            )

        case let .invoke(callee, arguments):
            try refuseConstruct(callee, at: place.slot(.callee))
            try validate(
                callee,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.callee)
            )

            for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                let here = place.argument(name)

                try normal(name, at: here)
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
            try refuseConstructCondition(condition, at: place.slot(.condition))
            try validate(
                condition,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.condition)
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
        // lets `where` read how many rounds have passed.
        case let .loop(condition, body, round):
            try introduced(round, beside: surroundings.constants, at: place)

            let inner = visible.union([round])

            try refuseConstructCondition(condition, at: place.slot(.condition))
            try validate(
                condition,
                visible: inner,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.condition)
            )
            try validate(
                body,
                visible: inner,
                variables: variables,
                surroundings: surroundings.inside(round),
                at: place
            )

        case let .iteration(material, body, element):
            try introduced(element, beside: surroundings.constants, at: place)

            try validate(
                material,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: place.slot(.material)
            )
            try validate(
                body,
                visible: visible.union([element]),
                variables: variables,
                surroundings: surroundings.inside(element),
                at: place.slot(.body)
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
                // trace — if the alternate path produces nothing, the author's
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

        case let .dispatch(dispatch):
            if let receiver = dispatch.receiver {
                try refuseConstruct(receiver, at: place.slot(.receiver))
                try validate(
                    receiver,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: place.slot(.receiver)
                )
            }

            for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
                let here = place.argument(name)

                try normal(name, at: here)
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

    // A construct that answers nothing — a branch, a walk — has nothing to
    // give a slot that exists to hold an answer. Refused for that reason
    // wherever one asks, rather than as a null that fails to fit downstream.
    private func refuseAnswerless(_ expression: Expression, at place: Place) throws {
        guard expression.answersNothing else { return }

        throw ValidationError(
            "this construct answers nothing, so it cannot"
                + " stand where a value is wanted",
            at: place
        )
    }

    // A call's operand is data the pure half reads — a document cannot even
    // write a construct there, and the run refuses one that arrives anyway.
    // Held here too, so a program assembled directly meets the same rule
    // before it runs — and at the link, which asks the same predicate, so a
    // program that skipped this door still cannot slip one through: the body
    // a word is to run travels as a closure, and there is no second channel
    // for bodies.
    private func refuseConstruct(_ expression: Expression, at place: Place) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError(Expression.constructInOperand, at: place)
    }

    // A condition is data by the same fact an operand is: the run asks it
    // purely. Refused with its own sentence, because the fix is different —
    // what a body decides reaches a condition through a word.
    private func refuseConstructCondition(_ expression: Expression, at place: Place) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError(Expression.constructInCondition, at: place)
    }

    private func validate(
        _ block: Block,
        visible: Set<String>,
        variables: Set<String> = [],
        declared: Set<String> = [],
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
            // trailing statement is — a body that left never reaches it.
            if block.body.alwaysLeaves {
                throw ValidationError(
                    "nothing runs after leaving,"
                        + " and this result would never be reached",
                    at: place.slot(.result)
                )
            }

            // A branch answers nothing, so a result slot — a place that
            // exists to hold an answer — has nothing to take from one.
            // Refused for that reason, rather than as a type that fails to
            // fit downstream.
            try refuseAnswerless(result, at: place.slot(.result))

            try validate(
                result,
                visible: inner,
                variables: variables,
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

        try normal(target, at: place)

        guard surroundings.rounds.contains(target) else {
            throw ValidationError(
                "names '\(target)', which is not a loop around it"
                    + " — the ones here are \(surroundings.rounds.reversed().joined(separator: ", "));"
                    + " the nearest is '\(nearest)'",
                at: place
            )
        }
    }

    private func validate(
        paths: [[PathSegment]],
        visible: Set<String>,
        at place: Place
    ) throws {
        for path in paths {
            for segment in path {
                if let name = segment.named {
                    try normal(name, at: place)
                }
            }

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
                        + " '\(head)', which is not visible here — declare it earlier"
                        + " or check the spelling",
                    at: place
                )
            }
        }
    }

    // One name, one spelling. Record keys settled this at the encodings; a name
    // a document writes as a value — a statement's, a binding's, a reference's
    // — settles here, so a declaration and a reference can only meet by being
    // the same bytes. Compared as bytes on purpose: Swift's `==` would call two
    // spellings equal, which is the confusion being refused.
    private func normal(_ name: String, at place: Place) throws {
        guard Name.isNormal(name) else {
            throw ValidationError(
                "the name '\(name)' is not in normal form C",
                at: place
            )
        }
    }

    // A name a body introduces: a parameter, a statement's id, or the one a
    // construct hands its body. Every such name passes here, so the module's
    // bound names are checked at whatever depth the name appears — a sub scope
    // is where a reader is least able to see that the spelling was taken.
    //
    // Linking folds a constant wherever its name is read, so a name introduced
    // under that spelling would never be the one that answers.
    private func introduced(
        _ name: String,
        beside constants: Set<String>,
        at place: Place
    ) throws {
        try normal(name, at: place)

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
// It is one value rather than a parameter each, because the parameters were
// individually forgettable and forgetting one was not an error — a body checked
// without its loops read as a body outside any loop, and a body checked without
// its boundary read as one whose outward writes were ordinary. Both of those
// were real: a `break` inside an `attempt` inside a loop was refused though it
// ran, and a closure's write to a captured name was nearly accepted.
//
// So the shape of this type is the point. Carrying it is the default, and every
// place that breaks it has to say so.
private struct Surroundings: Sendable {
    // MARK: - Property
    // The loops around here, nearest last. A name reaches past the nearer ones,
    // and nothing here means there is no loop to end.
    let rounds: [String]

    // Why a variable from outside cannot be written here, when it cannot — the
    // sentence the refusal says instead of "fixed name", which would be true
    // and useless. Nil where writing outward is ordinary.
    let boundary: String?

    // The module's bound names, carried so every signature met on the way —
    // a closure's included — refuses a parameter that would take one's
    // place: linking folds a constant wherever its name is read, so a
    // parameter under that name would never be the one that answers.
    let constants: Set<String>

    // A procedure's own body: no loop yet, nothing fenced.
    static let procedure = Surroundings(rounds: [], boundary: nil, constants: [])

    static func procedure(constants: Set<String>) -> Surroundings {
        Surroundings(rounds: [], boundary: nil, constants: constants)
    }

    // MARK: - Public
    func inside(_ round: String) -> Surroundings {
        Surroundings(rounds: rounds + [round], boundary: boundary, constants: constants)
    }

    // A procedure written inside another. It may be called anywhere and long
    // after, so the loops around where it was *written* are not around where it
    // runs — and its own answer is its own.
    var enclosed: Surroundings {
        Surroundings(
            rounds: [],
            boundary: "which lives outside this closure — a closure captures"
                + " values, and a name it captured is a value it captured",
            constants: constants
        )
    }

    // MARK: - Private
}

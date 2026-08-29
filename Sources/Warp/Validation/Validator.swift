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
        try validate(body, visible: visible, label: "lowered")
    }

    // A single expression, checked where a caller is about to evaluate one it
    // assembled itself.
    public func validate(_ expression: Expression, visible: Set<String>) throws {
        try validate(expression, visible: visible, at: "expression")
    }

    // Every declaration a module makes, in name order so the first refusal is
    // stable across runs. Nothing about the module as a whole is checked here —
    // whether its names collide with another module's is a link question, and
    // there is no other module in sight from inside one.
    public func validate(_ module: Module) throws {
        let constants = Set(module.constants.keys)

        // A constant sees no scope, so it may name another constant and nothing
        // else. Which is also why it is checked here rather than per procedure:
        // what it can see is a fact about the module.
        for (name, expression) in module.constants.sorted(by: { $0.key < $1.key }) {
            try normal(name, at: "const.\(name)")
            try validate(expression, visible: constants, at: "const.\(name)")
        }

        for name in module.procedures.keys.sorted() {
            try normal(name, at: name)
        }

        for name in module.procedures.keys.sorted() {
            guard let procedure = module.procedures[name] else { continue }

            do {
                try validate(procedure, constants: constants)
            } catch let error as ValidationError {
                throw ValidationError("\(name): \(error.message)")
            }
        }
    }

    // A parameter is a name the body can read, so it is visible from the first
    // statement — and declared, so a statement cannot introduce it again. The
    // body and the signature are one scope, and a name is introduced once in a
    // scope.
    public func validate(_ procedure: Procedure, constants: Set<String> = []) throws {
        let parameters = Set(procedure.signature.parameters.keys)

        for parameter in parameters.sorted() {
            try normal(parameter, at: "parameters.\(parameter)")
        }
        let colliding = parameters.intersection(constants).sorted()

        guard colliding.isEmpty else {
            throw ValidationError(
                "parameters: \(colliding.joined(separator: ", ")) collides with a name"
                    + " the module bound, which it would take the place of"
            )
        }

        // A constant is declared, not merely visible: linking folds a reference
        // to one into the value it holds, so a statement that reintroduced the
        // name would leave two readings of the same spelling and only one of
        // them true.
        guard let block = procedure.block else { return }

        try validate(
            block,
            visible: constants.union(parameters),
            declared: parameters.union(constants),
            surroundings: .procedure(constants: constants),
            at: "body"
        )
    }

    // MARK: - Private
    @discardableResult
    private func validate(
        _ body: [Statement],
        visible startVisible: Set<String>,
        variables startVariables: Set<String> = [],
        declared startDeclared: Set<String> = [],
        surroundings: Surroundings = .procedure,
        label: String
    ) throws -> Set<String> {
        var visible = startVisible
        var variables = startVariables
        var declared = startDeclared

        for (position, statement) in body.enumerated() {
            // A binding with no name is a write that goes nowhere. The document
            // reader cannot produce one — the binding comes from the naming key
            // — so this guards the caller that builds statements directly.
            if statement.id == nil, statement.binding != .constant {
                throw ValidationError(
                    "\(label)[\(position)]: writes no name, and a \(statement.binding)"
                        + " is a statement about its name"
                )
            }

            if let id = statement.id {
                guard !id.isEmpty else {
                    throw ValidationError("\(label): statement with empty id")
                }

                try normal(id, at: "\(label).\(id)")

                // The leave rules reach through structure, because the fact
                // does: every way through a leaving statement leaves, so its
                // name could never bind — refused before any question about
                // which name it is.
                if statement.expression.alwaysLeaves {
                    throw ValidationError(
                        "\(label).\(id): every way through this statement"
                            + " leaves, so its name could never bind — it takes"
                            + " no name"
                    )
                }

                // A walk answers nothing, so a `var` or `set` on one is a write
                // whose value could only ever be null. The plain name stands
                // for the element inside the body, and that is all it is.
                if statement.binding != .constant, isIteration(statement.expression) {
                    throw ValidationError(
                        "\(label).\(id): a walk answers nothing, so its name"
                            + " binds the element and no value — it is not"
                            + " writable"
                    )
                }

                // A branch answers nothing and binds nothing inside either, so
                // it takes no name at all: what an arm keeps it writes to an
                // outer variable, and a value leaves through `return`.
                if statement.expression.takesNoName {
                    throw ValidationError(
                        "\(label).\(id): a branch answers nothing, so its name"
                            + " could never bind — it takes no name"
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
                            "\(label): assigns '\(id)', \(reason)"
                        )
                    }
                }

                // Sub scopes restart declaration tracking, so an inner statement
                // may introduce a name an outer body also has — that is
                // shadowing, and it is a different name. Only same-level
                // duplicates are ambiguous.
                if case .assignment = statement.binding {} else {
                    guard !declared.contains(id) else {
                        throw ValidationError("\(label): duplicate statement id '\(id)'")
                    }

                    declared.insert(id)
                }
            }

            // Nothing runs after a statement that leaves — through structure
            // too: a branch both of whose arms leave never finishes either.
            if statement.expression.alwaysLeaves, position != body.count - 1 {
                throw ValidationError(
                    "\(label)[\(position)]: every way through this"
                        + " statement leaves, and what follows it here"
                        + " would never run"
                )
            }

            try validate(
                statement.expression,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(label).\(statement.id ?? "[\(position)]")"
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
        at location: String
    ) throws {
        switch expression {
        case .literal:
            return

        case let .reference(path):
            try validate(paths: path.expandingIndexReferences, visible: visible, at: location)

        case let .array(array):
            for element in array {
                try refuseAnswerless(element, at: location)
                try validate(element, visible: visible, variables: variables, surroundings: surroundings, at: location)
            }

        case let .record(record):
            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                try refuseAnswerless(field, at: "\(location).\(name)")
                try validate(
                    field,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).\(name)"
                )
            }

        // A cast names a shape and reads a value as it — the shape is the
        // link's to resolve, so the check has only the value to walk, exactly
        // as it walks any other operand.
        case let .cast(value, _, _):
            try refuseAnswerless(value, at: location)
            try validate(
                value,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: location
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
            try validate(leave, in: surroundings, at: location)

        case let .closure(procedure):
            let parameters = Set(procedure.signature.parameters.keys)

            // The same rule the top-level signature gets — a closure's
            // parameter is a name a body reads, wherever the signature sits.
            for parameter in parameters.sorted() {
                try normal(parameter, at: "\(location).\(parameter)")
            }

            // And the same collision rule: linking folds a constant wherever
            // its name is read, so a parameter under that name would never be
            // the one that answers — inside a closure as much as at the top.
            let colliding = parameters.intersection(surroundings.constants).sorted()

            guard colliding.isEmpty else {
                throw ValidationError(
                    "\(location): parameters \(colliding.joined(separator: ", "))"
                        + " collides with a name the module bound, which it"
                        + " would take the place of"
                )
            }

            guard let block = procedure.block else { return }

            try validate(
                block,
                visible: visible.union(parameters),
                declared: parameters,
                surroundings: surroundings.enclosed,
                at: "\(location).closure"
            )

        case let .invoke(callee, arguments):
            try refuseConstruct(callee, at: location)
            try validate(callee, visible: visible, variables: variables, surroundings: surroundings, at: location)

            for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                try normal(name, at: "\(location).\(name)")
                try refuseConstruct(argument, at: "\(location).\(name)")
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).\(name)"
                )
            }

        case let .block(block):
            try validate(block, visible: visible, variables: variables, surroundings: surroundings, at: location)

        case let .conditional(condition, then, otherwise):
            try refuseConstructCondition(condition, at: "\(location).when")
            try validate(
                condition,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).when"
            )
            try validate(
                then,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                label: "\(location).then"
            )

            if let otherwise {
                try validate(
                    otherwise,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    label: "\(location).else"
                )
            }

        // The round state is bound before the condition is asked, which is what
        // lets `while` read how many rounds have passed.
        case let .loop(condition, body, round):
            try normal(round, at: "\(location).round")

            let inner = visible.union([round])

            try refuseConstructCondition(condition, at: "\(location).while")
            try validate(
                condition,
                visible: inner,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).while"
            )
            try validate(
                body,
                visible: inner,
                variables: variables,
                surroundings: surroundings.inside(round),
                at: location
            )

        case let .iteration(material, body, element):
            try normal(element, at: "\(location).element")

            try validate(
                material,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).over"
            )
            try validate(
                body,
                visible: visible.union([element]),
                variables: variables,
                surroundings: surroundings.inside(element),
                label: location
            )

        // While the rescue runs, the failure is a value under the declared name.
        case let .attempt(block, rescue, failure):
            try normal(failure, at: "\(location).failure")

            try validate(
                block,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: location
            )

            guard !rescue.body.isEmpty || rescue.result != nil else {
                // An empty rescue would swallow a failure into null without a
                // trace — if the alternate path produces nothing, the author's
                // honest form is no rescue at all.
                throw ValidationError("\(location).rescue: must not be empty")
            }

            try validate(
                rescue,
                visible: visible.union([failure]),
                variables: variables,
                surroundings: surroundings,
                at: "\(location).rescue"
            )

        case let .dispatch(dispatch):
            if let receiver = dispatch.receiver {
                try refuseConstruct(receiver, at: location)
                try validate(
                    receiver,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: location
                )
            }

            for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
                try normal(name, at: "\(location).\(name)")
                try refuseConstruct(argument, at: "\(location).\(name)")
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).\(name)"
                )
            }

        }
    }

    // A construct that answers nothing — a branch, a walk — has nothing to
    // give a slot that exists to hold an answer. Refused for that reason
    // wherever one asks, rather than as a null that fails to fit downstream.
    private func refuseAnswerless(_ expression: Expression, at location: String) throws {
        guard expression.answersNothing else { return }

        throw ValidationError(
            "\(location): this construct answers nothing, so it cannot"
                + " stand where a value is wanted"
        )
    }

    // A call's operand is data the pure half reads — a document cannot even
    // write a construct there, and the run refuses one that arrives anyway.
    // Held here too, so a program assembled directly meets the same rule
    // before it runs — and at the link, which asks the same predicate, so a
    // program that skipped this door still cannot slip one through: the body
    // a word is to run travels as a closure, and there is no second channel
    // for bodies.
    private func refuseConstruct(_ expression: Expression, at location: String) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError("\(location): \(Expression.constructInOperand)")
    }

    // A condition is data by the same fact an operand is: the run asks it
    // purely. Refused with its own sentence, because the fix is different —
    // what a body decides reaches a condition through a word.
    private func refuseConstructCondition(_ expression: Expression, at location: String) throws {
        guard expression.holdsConstruct else { return }

        throw ValidationError("\(location): \(Expression.constructInCondition)")
    }

    private func validate(
        _ block: Block,
        visible: Set<String>,
        variables: Set<String> = [],
        declared: Set<String> = [],
        surroundings: Surroundings = .procedure,
        at location: String
    ) throws {
        let inner = try validate(
            block.body,
            visible: visible,
            variables: variables,
            declared: declared,
            surroundings: surroundings,
            label: location
        )

        if let result = block.result {
            // The result runs after the body, so it is "after" the same way a
            // trailing statement is — a body that left never reaches it.
            if block.body.alwaysLeaves {
                throw ValidationError(
                    "\(location).result: nothing runs after leaving,"
                        + " and this result would never be reached"
                )
            }

            // A branch answers nothing, so a result slot — a place that
            // exists to hold an answer — has nothing to take from one.
            // Refused for that reason, rather than as a type that fails to
            // fit downstream.
            try refuseAnswerless(result, at: "\(location).result")

            try validate(
                result,
                visible: inner,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).result"
            )
        }
    }

    // What a leave may say, and where it may say it.
    private func validate(
        _ leave: Leave,
        in surroundings: Surroundings,
        at location: String
    ) throws {
        guard leave.reach != .procedure else {
            guard leave.target == nil else {
                throw ValidationError(
                    "\(location): answering leaves the procedure it is written in,"
                        + " and names no other"
                )
            }

            return
        }

        guard leave.value == nil else {
            throw ValidationError(
                "\(location): a loop answers what it was going to answer,"
                    + " so ending one carries nothing"
            )
        }

        guard let nearest = surroundings.rounds.last else {
            throw ValidationError("\(location): there is no loop here to leave")
        }

        guard let target = leave.target else { return }

        try normal(target, at: location)

        guard surroundings.rounds.contains(target) else {
            throw ValidationError(
                "\(location): names '\(target)', which is not a loop around it"
                    + " — the ones here are \(surroundings.rounds.reversed().joined(separator: ", "));"
                    + " the nearest is '\(nearest)'"
            )
        }
    }

    private func validate(
        paths: [[PathSegment]],
        visible: Set<String>,
        at location: String
    ) throws {
        for path in paths {
            for segment in path {
                if let name = segment.named {
                    try normal(name, at: location)
                }
            }

            if let refusal = path.markedHead {
                throw ValidationError("\(location): \(refusal)")
            }

            guard let head = path.head else {
                throw ValidationError(
                    "\(location): reference { ref: \(path.rendered) } does not"
                        + " start with a name"
                )
            }

            guard visible.contains(head) else {
                throw ValidationError(
                    "\(location): reference { ref: \(path.rendered) } names"
                        + " '\(head)', which is not visible here — declare it earlier"
                        + " or check the spelling"
                )
            }
        }
    }

    // One name, one spelling. Record keys settled this at the encodings; a name
    // a document writes as a value — a statement's, a binding's, a reference's
    // — settles here, so a declaration and a reference can only meet by being
    // the same bytes. Compared as bytes on purpose: Swift's `==` would call two
    // spellings equal, which is the confusion being refused.
    private func normal(_ name: String, at location: String) throws {
        guard Name.isNormal(name) else {
            throw ValidationError(
                "\(location): the name '\(name)' is not in normal form C"
            )
        }
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
    // after, so the loops around where it was written are not around where it
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

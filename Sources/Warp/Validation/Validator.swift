//
//  Validator.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Checks a module against itself, before anything is resolved: what its text
// answers alone. Every name a procedure reads is one it can see, every name it
// writes holds the grammar of where it is written, and every word a type
// writes stands where it may.
//
// The walk is structural: a call's arguments are expressions whose insides
// this reads, so validation never consults the procedure table.
struct Validator: Sendable {
    // MARK: - Property
    // What a declared name that comes back to itself is refused with, by a
    // document's load and by an object's reading alike.
    static let comingBack = "names itself through what it stands for, and no type spells itself."
        + " A type that holds itself is a declared record"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // Every declaration a module makes, in name order so the first refusal is
    // stable across runs. Whether its names collide with another module's is a
    // link question, and there is no other module in sight from inside one.
    func validate(_ module: Module) throws {
        try hosted(module)

        let constants = Set(module.constants.keys)
        let variables = Set(module.variables.keys)
        let bound = constants.union(variables)

        // A constant sees no scope, so it may name another constant and nothing
        // else.
        for (name, expression) in module.constants.sorted(by: { one, other in one.key < other.key }) {
            try held(name, as: .value, at: .constant(name.spelling, in: .of(module)))
            try held(expression, asOperand: .constant(name.spelling, in: .of(module)))

            try validate(
                expression,
                naming: nil,
                visible: constants,
                variables: [],
                scope: .procedure(bound: bound),
                at: .constant(name.spelling, in: .of(module))
            )
        }

        try acyclic(module.constants, in: module)

        // A variable's start is written like a constant and sees what a
        // constant sees: the constants beside it, and no variable. A variable
        // holds nothing until the run starts.
        for (name, variable) in module.variables.sorted(by: { one, other in one.key < other.key }) {
            try held(name, as: .value, at: .variable(name.spelling, in: .of(module)))

            guard !constants.contains(name) else {
                throw ValidationError(
                    "'\(name)' is declared as a constant and as a variable, and"
                        + " one name holds one thing",
                    at: .variable(name.spelling, in: .of(module))
                )
            }

            try held(variable.start, asOperand: .variable(name.spelling, in: .of(module)))
            try validate(
                variable.start,
                naming: nil,
                visible: constants,
                variables: [],
                scope: .procedure(bound: bound),
                at: .variable(name.spelling, in: .of(module))
            )

            if let declared = variable.declared {
                try written(declared, in: .value, at: .variable(name.spelling, in: .of(module)))
            }
        }

        for (name, type) in module.types.sorted(by: { one, other in one.key < other.key }) {
            try held(name, as: .type, at: .type(name.spelling, in: .of(module)))
            try written(type, in: .declaration, at: .type(name.spelling, in: .of(module)))

            guard !comesBack(name, in: module.types) else {
                throw ValidationError(Self.comingBack, at: .type(name.spelling, in: .of(module)))
            }
        }

        for (contract, procedures) in module.contracts.sorted(by: { one, other in one.key < other.key }) {
            try held(contract, as: .type, at: .contract(contract.spelling, in: .of(module)))

            for (name, asked) in procedures.sorted(by: { one, other in one.key < other.key }) {
                let place = Place.contract(contract.spelling, in: .of(module)).key(name.spelling)

                try held(name, as: .contractProcedure, at: place)

                // A bound is declared by the procedure whose call fills the
                // name, and a contract's procedure is answered by declarations
                // that each declare their own.
                guard asked.signature.bounds.isEmpty else {
                    throw ValidationError(
                        "a contract's procedure writes no bounds. A bound is declared in the `bounds`"
                            + " of a procedure's own signature",
                        at: place.part(.bounds)
                    )
                }

                // Each is answered about the value it takes first, so that
                // value is written `Self`, the type that answers the contract.
                // A value and not a place: a call through the contract picks
                // the declaration by the value standing there.
                guard asked.signature.parameters.first?.type == .selfType else {
                    throw ValidationError(
                        "takes \(asked.signature.parameters.first?.type.rendered ?? "nothing") first."
                            + " A contract's procedure takes `Self` first: the value it is"
                            + " answered about, of the type that answers it",
                        at: place.part(.parameters)
                    )
                }

                try validate(asked.signature, in: .contract, at: place)
            }
        }

        // A claim names two types: the one it is about and the contract it
        // says that type answers. A claim about a type the language names a
        // value an instance of (`Int`, `Array`) is about no declaration, so
        // its key is that type's and no name a document writes.
        for (type, contracts) in module.claims.sorted(by: { one, other in one.key < other.key }) {
            let place = Place.satisfies(type.spelling, in: .of(module))

            if TypeExpression.nominalTypes[type] == nil {
                try held(type, as: .type, at: place)
            }

            for contract in contracts.sorted() {
                try held(contract, as: .type, at: place)
            }
        }

        for (name, procedure) in module.procedures.sorted(by: { one, other in one.key < other.key }) {
            try validate(
                procedure,
                constants: constants,
                variables: variables,
                at: .procedure(name.spelling, in: .of(module))
            )
        }

        // Last, so a module whose declarations refuse is refused for them
        // before its list.
        try declared(module)
    }

    // Whether a declared name that is no record comes back to itself through
    // the names it mentions, at any depth: a spelling that reaches itself
    // spells no type, and a type that holds itself is a declared record. A
    // record on the way stands as its own name, so the walk stops there. Asked
    // of every module's types here and of every object's where it is read, so
    // no later stage meets one.
    func comesBack(_ name: Name, in types: [Name: TypeExpression]) -> Bool {
        func standsAsAName(_ mentioned: Name) -> Bool {
            if case .record = types[mentioned] { true } else { false }
        }

        guard let declared = types[name], !standsAsAName(name) else { return false }

        var walked: Set<Name> = []
        var waiting = [declared]

        while let type = waiting.popLast() {
            for mentioned in type.mentions where !standsAsAName(mentioned) {
                guard mentioned != name else { return true }

                if walked.insert(mentioned).inserted, let next = types[mentioned] {
                    waiting.append(next)
                }
            }
        }

        return false
    }

    // MARK: - Private
    // What a module says it imports against what it uses: the procedures it
    // sends and the types and contracts it names. A host reads the list to
    // decide what to grant and what to lay in the link before it links
    // anything.
    private func declared(_ module: Module) throws {
        let used = Set(module.references.map(\.name))

        let undisclosed = used.subtracting(module.imports).sorted().map(\.spelling)
        let unspent = module.imports
            .filter { name in !used.contains(name) }
            .sorted()
            .map(\.spelling)

        guard !undisclosed.isEmpty || !unspent.isEmpty else { return }

        // The two differences, each its own mistake: a name used and not
        // listed, and a name listed and not used.
        let said = [
            undisclosed.isEmpty ? nil : "uses \(undisclosed), which it does not import",
            unspent.isEmpty ? nil : "imports \(unspent), which it does not use"
        ]

        throw ValidationError(
            said.compactMap { said in said }.joined(separator: ", and "),
            at: Place([.part(.imports)], in: .of(module))
        )
    }

    // A constant settles from what it names, so constants that name each
    // other back have nothing to settle from. Refused standing on one of
    // them.
    private func acyclic(_ constants: [Name: Expression], in module: Module) throws {
        var settled: Set<Name> = []

        // What the walk is standing on, root first. Where it meets a name
        // already on it, everything from that name down is the cycle, and
        // nothing above it is, which is the difference between what names
        // itself back and what merely waits on something that does.
        var walking: [Name] = []

        func walk(_ name: Name, reading expression: Expression) throws {
            guard !settled.contains(name) else { return }

            if let met = walking.firstIndex(of: name) {
                let cycle = walking[met...].sorted()

                throw ValidationError(
                    "constants \(cycle.map(\.spelling).joined(separator: ", ")) name each other in a"
                        + " cycle. A constant may name another declared beside it, but"
                        + " not one that names it back",
                    // The first in name order, so the refusal names one
                    // constant wherever the walk started.
                    at: .constant(cycle[0].spelling, in: .of(module))
                )
            }

            walking.append(name)

            // Sorted, so a module with two mistakes in it refuses the same one
            // every run. What a set hands back is seeded per process.
            for read in expression.pathHeads.sorted() {
                guard let reading = constants[read] else { continue }

                try walk(read, reading: reading)
            }

            walking.removeLast()
            settled.insert(name)
        }

        for (name, expression) in constants.sorted(by: { one, other in one.key < other.key }) {
            try walk(name, reading: expression)
        }
    }

    // A private procedure is named by its document, and the code a host
    // brings for one is joined to it by that document. A module that is no
    // document has nothing to join it by.
    private func hosted(_ module: Module) throws {
        guard module.identity == nil else { return }

        for (name, procedure) in module.procedures.sorted(by: { one, other in one.key < other.key })
        where procedure.implementation.native != nil && !procedure.access.reachesOtherDocuments {
            throw ValidationError(
                "this procedure is private and answered by the host in a module that is no document,"
                    + " and a private procedure is named by its document",
                at: .procedure(name.spelling, in: .of(module))
            )
        }
    }

    // A parameter is a name the body can read, so it is visible from the first
    // statement, and no name the body introduces, at any depth, takes its
    // spelling.
    private func validate(
        _ procedure: Procedure,
        constants: Set<Name>,
        variables: Set<Name>,
        at place: Place
    ) throws {
        let parameters = Set(procedure.signature.names)
        let bound = constants.union(variables)

        try validate(procedure.signature, in: .signature, at: place)

        for (position, parameter) in procedure.signature.names.enumerated() {
            try collides(parameter, in: .procedure(bound: bound), at: place.part(.parameters).index(position))
        }

        try reads(procedure, at: place)
        try sends(procedure, at: place)

        guard let block = procedure.block else { return }

        // A parameter handed in place is a variable in the body: the box is
        // the caller's, and writing it is what the parameter is for.
        try validate(
            block,
            visible: bound.union(parameters),
            variables: variables.union(parameters).subtracting(procedure.signature.ownedParameters),
            scope: .procedure(
                bound: bound,
                parameters: parameters,
                typeParameters: procedure.signature.parameterNames
            ),
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
        variables startVariables: Set<Name>,
        scope: Scope,
        at place: Place
    ) throws -> (visible: Set<Name>, variables: Set<Name>) {
        var visible = startVisible
        var variables = startVariables
        var declared: Set<Name> = []

        for (position, statement) in body.statements.enumerated() {
            // A statement is its name and the construct it writes under. Both,
            // because a document writes both and following one at a time is
            // what a place is for.
            let here = place.statement(statement, at: position)

            if let binding = statement.binding {
                if statement.expression.alwaysLeaves {
                    throw ValidationError(Expression.nameOnWhatNeverFinishes, at: here)
                }

                if statement.expression.answersNothing {
                    throw ValidationError(
                        "a conditional answers nothing, so its name"
                            + " could never bind. It takes no name; what an arm"
                            + " keeps is written to an outer variable with 'set'",
                        at: here
                    )
                }

                if binding.declared != nil, statement.expression.namesItsOwn {
                    throw ValidationError(Expression.declarationOnABoundName, at: here)
                }

                // What a name says it holds, the name itself and the path a
                // write names are the statement's, beside the construct it
                // writes.
                let named = place.statement(statement.name?.spelling, at: position)

                if let declared = binding.declared {
                    try written(declared, in: .value, at: named)
                }

                switch binding {
                case let .constant(name, _), let .variable(name, _):
                    try held(name, as: .value, at: named)
                    try collides(name, in: scope, at: named)

                    guard !declared.contains(name) else {
                        throw ValidationError("two statements here are named '\(name)'", at: named)
                    }

                    declared.insert(name)

                // A write names a path, and the head of the path is the
                // variable it writes. An index the path reads by a name is a
                // path read like any other. The rest of the path is judged at
                // the build, where the variable's type is known.
                case let .assignment(path):
                    if let refusal = path.markedHead ?? path.writtenThroughAbsence {
                        throw ValidationError(refusal, at: named)
                    }

                    try held(steps: path, at: named)
                    try validate(paths: Array(path.expandingIndexReferences.dropFirst()), visible: visible, at: named)

                    guard let head = path.head else {
                        throw ValidationError(
                            "writes a path headed by no name. A write starts at a variable",
                            at: named
                        )
                    }

                    guard variables.contains(head) else {
                        let reason = if visible.contains(head) {
                            "which is a fixed name here. Declare it as a variable to write it"
                        } else {
                            "which is not visible here. Declare it earlier or check the spelling"
                        }

                        throw ValidationError("assigns '\(head)', \(reason)", at: named)
                    }
                }
            }

            if statement.expression.alwaysLeaves, position != body.statements.count - 1 {
                throw ValidationError(Expression.afterWhatNeverFinishes, at: here)
            }

            try validate(
                statement.expression,
                naming: statement.binding?.introduced,
                visible: visible,
                variables: variables,
                scope: scope,
                at: here
            )

            switch statement.binding {
            case let .constant(name, _)?:
                visible.insert(name)
                variables.remove(name)

            case let .variable(name, _)?:
                visible.insert(name)
                variables.insert(name)

            case .assignment?, nil:
                break
            }
        }

        return (visible, variables)
    }

    // `name` is what the statement this expression is the value of
    // introduces, which a loop binds its round under and an attempt its
    // failure. The statement already held it to where a name may be
    // introduced.
    private func validate(
        _ expression: Expression,
        naming name: Name?,
        visible: Set<Name>,
        variables: Set<Name>,
        scope: Scope,
        at place: Place
    ) throws {
        switch expression {
        // A literal is data. One kind a value has is not data (a closure is
        // made by running the expression that writes one) so a program carrying
        // one as a literal is carrying something no text spells and nothing
        // reads back. A caller assembling a program in Swift is the only one that
        // can build it, and this is the door it comes through. Nor does a
        // literal name a record: a name is a type's, and a literal written
        // with one would hold a value of a type nothing declared or imported.
        case let .literal(value):
            guard !value.holdsProcedure else {
                throw ValidationError(Value.procedureIsNotData, at: place)
            }

            guard !value.holdsName else {
                throw ValidationError(
                    "a literal writes a record's name, and a record takes one only from a declared record"
                        + " it is written into, a door it comes through or a cast",
                    at: place
                )
            }

            guard !value.holdsDictionary else {
                throw ValidationError(
                    "a literal holds a map, and a map is written as a record cast to the `Dictionary<T>` it is",
                    at: place
                )
            }

        case let .reference(path):
            try validate(paths: path.expandingIndexReferences, visible: visible, at: place)

        case let .array(array):
            for (position, element) in array.enumerated() {
                let here = place.child(.element(position))

                try held(element, asValueAt: here)
                try validate(element, naming: nil, visible: visible, variables: variables, scope: scope, at: here)
            }

        case let .record(record):
            for (name, field) in record.sorted(by: { one, other in one.key < other.key }) {
                let here = place.child(.field(name))

                try held(field, asValueAt: here)
                try validate(field, naming: nil, visible: visible, variables: variables, scope: scope, at: here)
            }

        // A cast names a type and reads a value as it. The type is the build's
        // to resolve, so the check has only the value to walk, exactly as it
        // walks any other operand.
        case let .cast(value, type, optional):
            try written(type, in: .value, at: place)
            try held(value, asValueAt: place.child(.subject(optional: optional)))
            try validate(
                value,
                naming: nil,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.child(.subject(optional: optional))
            )

        case let .leave(leave):
            try validate(leave, in: scope, at: place)

            // What a `return` carries is a value like any other. A name it
            // reads has to be visible where it was written. Only `return`
            // reaches here with one: the check above refuses a value on the two
            // that end a loop.
            guard let value = leave.value else { return }

            try held(value, asValueAt: place.child(.held))
            try validate(
                value,
                naming: nil,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.child(.held)
            )

        // A closure sees where it was written plus what it declares, which is
        // the capture read statically. Its parameters hold for its body the way
        // a procedure's do, and it is written inside the parameters around it.
        // It is a body written where it stands, so it is never the host's code.
        case let .closure(procedure):
            guard let block = procedure.block else {
                throw ValidationError("a closure is a body, and this one is the host's code", at: place)
            }

            let inside = place.child(.closure)
            let parameters = Set(procedure.signature.names)

            // Its `some T` is the `T` of the procedure it is written in, and
            // the signature that declares a type parameter owns its bound.
            guard procedure.signature.bounds.isEmpty else {
                throw ValidationError(
                    "a closure writes no bounds. Its `some T` is the `T` of the procedure it is written in,"
                        + " held to the bounds that procedure declares",
                    at: inside
                )
            }

            // The row a closure is lifted into is its document's alone.
            guard procedure.access == .internal else {
                throw ValidationError(
                    "a closure writes no access. Access says who may name a declaration, and nothing names a closure",
                    at: inside
                )
            }

            try validate(procedure.signature, in: .closure(of: scope.typeParameters), at: inside)

            // The same rule the top-level signature gets. A closure's parameter
            // is a name a body reads, wherever the signature sits.
            for (position, parameter) in procedure.signature.names.enumerated() {
                try collides(parameter, in: scope, at: inside.part(.parameters).index(position))
            }

            // A parameter it takes in place is a variable in its body, the way
            // a declaration's is.
            try validate(
                block,
                visible: visible.union(parameters),
                variables: variables.union(parameters).subtracting(procedure.signature.ownedParameters),
                scope: scope.enclosed(taking: parameters),
                at: inside
            )

        case let .apply(callee, arguments):
            try held(callee, asOperand: place.child(.callee))
            try validate(
                callee,
                naming: nil,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.child(.callee)
            )

            for (position, argument) in arguments.enumerated() {
                let here = place.child(.argument(position))

                try held(argument, asOperand: here)
                try validate(
                    argument,
                    naming: nil,
                    visible: visible,
                    variables: variables,
                    scope: scope,
                    at: here
                )
            }

        case let .block(block):
            try validate(block, visible: visible, variables: variables, scope: scope, at: place.child(.held))

        case let .conditional(condition, then, otherwise):
            try held(condition, asOperand: place.child(.condition(of: .conditional)))
            try validate(
                condition,
                naming: nil,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.child(.condition(of: .conditional))
            )
            try validate(
                then,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.child(.then)
            )

            if let otherwise {
                try validate(
                    otherwise,
                    visible: visible,
                    variables: variables,
                    scope: scope,
                    at: place.child(.otherwise)
                )
            }

        // The round state is bound before the condition is asked, which is what
        // lets `while` read how many rounds have passed.
        case let .loop(condition, body):
            let round = name
            let inner = visible.union(round.map { round in [round] } ?? [])

            try held(condition, asOperand: place.child(.condition(of: .loop)))
            try validate(
                condition,
                naming: nil,
                visible: inner,
                variables: variables,
                scope: scope,
                at: place.child(.condition(of: .loop))
            )
            try validate(
                body,
                visible: inner,
                variables: variables,
                scope: scope.inside(round),
                at: place.child(.held)
            )

        // While the rescue runs, the failure is a value under the declared name.
        case let .attempt(block, rescue):
            let failure = name

            try validate(
                block,
                visible: visible,
                variables: variables,
                scope: scope,
                at: place.child(.held)
            )

            guard !rescue.body.statements.isEmpty || rescue.result != nil else {
                // A rescue answers for the failure it caught, and an empty
                // one answers nothing.
                throw ValidationError("must not be empty", at: place.child(.rescue))
            }

            try validate(
                rescue,
                visible: visible.union(failure.map { failure in [failure] } ?? []),
                variables: variables,
                scope: scope,
                at: place.child(.rescue)
            )

        case let .call(call):
            for (position, argument) in call.arguments.enumerated() {
                let here = place.child(.argument(position))

                try held(argument, asOperand: here)
                try validate(
                    argument,
                    naming: nil,
                    visible: visible,
                    variables: variables,
                    scope: scope,
                    at: here
                )
            }
        }
    }

    // A construct runs a body, so it stands as a statement's value and nowhere
    // a value is wanted: an operand, an element, a field, what a cast reads,
    // what `return` carries and a block's result.
    private func held(_ expression: Expression, asValueAt place: Place) throws {
        guard !expression.holdsConstruct else {
            throw ValidationError(Expression.constructWhereAValueIsWanted, at: place)
        }
    }

    // An operand is data the run reads rather than runs: a call's and a value
    // call's operands, a condition, a constant and a variable's start. Which
    // procedure a value is, is the run's answer, so calling one is running.
    private func held(_ expression: Expression, asOperand place: Place) throws {
        try held(expression, asValueAt: place)

        guard !expression.callsValue else {
            throw ValidationError(Expression.valueCallInOperand, at: place)
        }
    }

    private func validate(
        _ block: Block,
        visible: Set<Name>,
        variables: Set<Name>,
        scope: Scope,
        at place: Place
    ) throws {
        let inner = try validate(
            block.body,
            visible: visible,
            variables: variables,
            scope: scope,
            at: place.child(.body)
        )

        if let result = block.result {
            // The result runs after the body, so it is "after" the same way a
            // trailing statement is. A body that left never reaches it.
            if block.body.alwaysLeaves {
                throw ValidationError(Expression.resultAfterWhatNeverFinishes, at: place.child(.result))
            }

            try held(result, asValueAt: place.child(.result))

            try validate(
                result,
                naming: nil,
                visible: inner.visible,
                variables: inner.variables,
                scope: scope,
                at: place.child(.result)
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
            let around = scope.rounds.reversed().map { round in round?.spelling ?? "a nameless one" }

            throw ValidationError(
                "names '\(target)', which is not a loop around it."
                    + " The ones here are \(around.joined(separator: ", "));"
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

            try held(steps: path, at: place)

            guard let head = path.head else {
                throw ValidationError("'\(path.rendered)' starts with no name, and a path reads from one", at: place)
            }

            guard visible.contains(head) else {
                throw ValidationError(
                    "'\(path.rendered)' reads '\(head)', which is not visible here. Declare it earlier"
                        + " or check the spelling",
                    at: place
                )
            }
        }
    }

    // What a path's steps are held to wherever it is written: a name it
    // reads is a value's, the one name a path reads back as one key, and a
    // whole number written between the brackets is a position, which one
    // below zero is not.
    private func held(steps path: Path, at place: Place) throws {
        for segment in path.segments {
            switch segment {
            case let .key(name, _):
                try held(name, as: .value, at: place)

            case let .index(index, _) where index < 0:
                throw ValidationError(
                    "index segment '[\(index)]' is below zero, and a whole number below zero is no position",
                    at: place
                )

            case .index, .indexRef:
                continue
            }
        }
    }

    // What a signature is held to wherever it is written: one name to each
    // parameter, since two under one name would be one name a body reads two
    // ways, each parameter's type, in front of which `inout` may stand, and
    // the answer's, and a bound only on a name some slot writes as `some T`,
    // since one on a name nobody wrote binds nothing.
    private func validate(_ signature: Signature, in context: TypeContext, at place: Place) throws {
        for (parameter, contracts) in signature.bounds.sorted(by: { one, other in one.key < other.key }) {
            let here = place.part(.bounds).key(parameter.spelling)

            try held(parameter, as: .typeParameter, at: here)

            for contract in contracts.sorted() {
                try held(contract, as: .type, at: here)
            }
        }

        let named = signature.parameterNames
        let unwritten = signature.bounds.keys.filter { name in !named.contains(name) }.sorted()

        if let first = unwritten.first {
            throw ValidationError(
                "bounds name \(unwritten.map(\.spelling).joined(separator: ", ")), and no slot writes"
                    + " `some \(first.spelling)`. A bound rides on a parameter some slot mentions",
                at: place.part(.bounds)
            )
        }

        for (position, parameter) in signature.parameters.enumerated() {
            let here = place.part(.parameters).index(position)

            try held(parameter.name, as: .value, at: here)

            guard !signature.parameters[..<position].contains(where: { earlier in earlier.name == parameter.name }) else {
                throw ValidationError("declares '\(parameter.name)' twice", at: here)
            }

            try marked(parameter.type, at: here)
            try written(parameter.type.slotUnwrapped, in: context, at: here)
        }

        if let returns = signature.returns {
            try written(returns, in: context, at: place.part(.returns))
        }
    }

    // A type held to where it is written: every name in it holding its
    // grammar, `inout` only in front of a parameter, `var` only on a field of
    // a type declared in `types`, a type parameter only where a call fills it,
    // `Self` only in a contract's procedures, and `?` only where it says
    // something new. What a name stands for is the build's to resolve, so a
    // name is not walked into.
    private func written(_ type: TypeExpression, in context: TypeContext, at place: Place) throws {
        switch type {
        case .any, .never, .null, .bool, .int, .double, .string:
            return

        case let .named(name):
            try held(name, as: .type, at: place)

        // One contract is written by its name, so a composition joins two
        // or more.
        case let .composition(names):
            guard names.count > 1 else {
                throw ValidationError(
                    "joins \(names.count) with `&`, and `&` joins two contracts or more."
                        + " One contract is written by its name",
                    at: place
                )
            }

            for name in names.sorted() {
                try held(name, as: .type, at: place)
            }

        // The build's own note to itself: a type it read out of a body, which
        // nobody declared and no document spells.
        case let .projection(of, path):
            throw ValidationError(
                "writes `\(type.rendered)`, which is a type the build"
                    + " read out of a body. A declaration says what a call fills,"
                    + " and `\(Path([.key(of)] + path.segments).rendered)` is a path"
                    + " only that body can read",
                at: place
            )

        case .selfType:
            guard context.takesSelf else {
                throw ValidationError(
                    "writes `Self`, which stands for the type that answers a contract"
                        + " and is written in that contract's procedures alone",
                    at: place
                )
            }

        case let .parameter(name):
            guard context.takes(typeParameter: name) else {
                throw ValidationError(
                    "writes `\(type.rendered)`, and nothing here is"
                        + " filled by a call. A type parameter lives in a signature",
                    at: place
                )
            }

            try held(name, as: .typeParameter, at: place)

        case let .array(inner), let .dictionary(inner):
            try written(inner, in: context.nested, at: place)

        // What a `?` wraps behind a name is the build's, where names resolve.
        case let .nullable(inner):
            guard inner.takesQuestionMark else {
                throw ValidationError("writes `\(type.rendered)`, and a `?` says nothing on \(inner.rendered)", at: place)
            }

            guard inner.hasSpelling else {
                throw ValidationError(
                    "writes `\(type.rendered)`, and a `?` trails a type's spelling, which \(inner.rendered) is"
                        + " written without. What may be null of it is declared under a name and written `Name?`",
                    at: place
                )
            }

            try written(inner, in: context.nested, at: place)

        // A field of a record type is reached by a path alone, so its name is
        // a value's.
        case let .record(fields):
            for (name, field) in fields.sorted(by: { one, other in one.key < other.key }) {
                let here = place.part(.fields).key(name.spelling)

                try held(name, as: .value, at: here)

                if context.takesWritableFields {
                    try marked(field, at: here)
                }

                try written(context.takesWritableFields ? field.fieldUnwrapped : field, in: context.nested, at: here)
            }

        // A procedure type's parameters are slots, each of which may be
        // handed in place.
        case let .procedure(procedure, _, _):
            guard let procedure else { return }

            for (position, parameter) in procedure.parameters.enumerated() {
                try marked(parameter, at: place.index(position))
                try written(parameter.slotUnwrapped, in: context.nested, at: place.index(position))
            }

            try written(procedure.returns ?? .any, in: context.nested, at: place.part(.returns))

        case .inout:
            throw ValidationError(
                "writes `\(type.rendered)`, and only a parameter is handed a"
                    + " variable in place. `inout` is written on a parameter's type",
                at: place
            )

        case .variable:
            throw ValidationError(
                "writes `\(type.rendered)`, and `var` is written on a field of the record a type in"
                    + " `types` declares. Any other record's field is written through as it is",
                at: place
            )
        }
    }

    // A slot mark stands in front of a type's spelling or on the key a
    // procedure type is written under, and a type written as any other
    // mapping has no front for one.
    private func marked(_ type: TypeExpression, at place: Place) throws {
        switch type {
        case let .inout(inner), let .variable(inner):
            if inner.hasSpelling { return }

            if case .procedure(.some, _, _) = inner { return }

            throw ValidationError(
                "writes `\(type.rendered)`, and a mark stands in front of a type's spelling or on a procedure"
                    + " type's key, which \(inner.rendered) is written without. Declare it under a name and"
                    + " mark the name",
                at: place
            )

        default:
            return
        }
    }

    // A name held to the grammar of where it is written.
    private func held(_ name: Name, as grammar: NameGrammar, at place: Place) throws {
        guard !grammar.holds(name) else { return }

        throw ValidationError(grammar.refusal(of: name), at: place)
    }

    // A name a body introduces: a parameter, a statement's name, or the one a
    // construct hands its body. Every such name passes here, so the module's
    // bound names and the parameters around it are checked at whatever depth
    // the name appears. A parameter's grammar is its signature's.
    //
    // A module's constant is folded wherever its name is read and its variable
    // is read through the module's box, so a name introduced under either
    // spelling would never be the one that answers.
    private func collides(
        _ name: Name,
        in scope: Scope,
        at place: Place
    ) throws {
        if scope.bound.contains(name) {
            throw ValidationError(
                "'\(name)' collides with a name the module bound, which it would"
                    + " take the place of",
                at: place
            )
        }

        if scope.parameters.contains(name) {
            throw ValidationError(
                "'\(name)' is a parameter of the procedure this is written in,"
                    + " and a name inside it does not take a parameter's spelling",
                at: place
            )
        }
    }
}

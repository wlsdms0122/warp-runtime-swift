//
//  Derivation.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// The facts nobody declared, worked out over a document's declarations at
// once: constness, isolation and what may fail. Each is a fixed point over what
// the bodies reach.
struct Derivation {
    // What a body is walked for. Constness and isolation are read by one walk
    // and differ only in these: which callee holds the fact, which slot says a
    // procedure it holds does, and which names a body loses it by reading.
    private struct Fact {
        // MARK: - Property
        let callee: (Name) -> Bool
        let slot: (TypeExpression) -> Bool
        let unread: Set<Name>

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls. What is settled grows in
    // place: a document is settled against everything standing in front of
    // it, and this call only ever adds its own.
    //
    // `beyond` answers for a selector this document does not declare: the
    // row it names in the link, which carries its constness.
    func const(
        among symbols: [Symbol],
        settling const: inout Set<Name>,
        reading variables: Set<Name>,
        taking asked: @escaping (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool
    ) {
        // A body may write what its signature owns: a parameter handed in
        // place is the caller's box, not the body's own.
        strike(
            among: symbols,
            settling: &const,
            natively: { implementation in implementation.isNativelyConst != false },
            declaring: \.ownedParameters,
            applying: \.constProcedures,
            fact: { given in Fact(callee: given, slot: \.isConstProcedure, unread: variables) },
            taking: asked,
            beyond: beyond
        )
    }

    // Which declarations touch no name another body could touch at the same
    // time. A native says so about itself; a body is read off what it writes
    // and calls.
    func isolated(
        among symbols: [Symbol],
        settling isolated: inout Set<Name>,
        taking asked: @escaping (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool
    ) {
        strike(
            among: symbols,
            settling: &isolated,
            natively: { implementation in implementation.isNativelyIsolated != false },
            declaring: { signature in Set(signature.names) },
            applying: \.isolatedProcedures,
            fact: { given in Fact(callee: given, slot: \.isIsolatedProcedure, unread: []) },
            taking: asked,
            beyond: beyond
        )
    }

    // What may come out of each of these when the work goes wrong. A native
    // says so about itself; a body is read off what it casts, calls and
    // rescues.
    //
    // Grown rather than struck out, the opposite of constness and isolation: a
    // body starts failing nothing and gains what it reaches, and a declaration
    // that says nothing about itself makes everything reaching it say nothing
    // too. Two procedures calling each other settle where nothing more is
    // added, which the finite set of declared names guarantees.
    func failing(
        among symbols: [Symbol],
        settling failing: inout [Name: Failing],
        beyond: @escaping (Name) -> Failing?
    ) {
        let own = Set(symbols.map(\.declared))

        for symbol in symbols {
            failing[symbol.declared] = symbol.procedure.implementation.nativelyFailing ?? .these([])
        }

        let bodies = symbols
            .compactMap { symbol in symbol.procedure.block.map { block in (symbol.declared, block) } }
            .sorted { $0.0 < $1.0 }

        while true {
            var grown = false

            for (name, block) in bodies {
                let settled = failing
                let read = self.failing(block, given: { selector in own.contains(selector) ? settled[selector] : beyond(selector) })

                guard read != failing[name] else { continue }

                failing[name] = read
                grown = true
            }

            guard grown else { return }
        }
    }

    // What may come out of a block: everything its statements and its result
    // may fail with.
    func failing(_ block: Block, given failing: (Name) -> Failing?) -> Failing {
        block.body.statements
            .reduce(Failing.these([])) { carried, statement in
                carried.joined(self.failing(statement.expression, given: failing))
            }
            .joined(block.result.map { result in self.failing(result, given: failing) } ?? .these([]))
    }

    func failing(_ body: Body, given failing: (Name) -> Failing?) -> Failing {
        body.statements.reduce(Failing.these([])) { carried, statement in
            carried.joined(self.failing(statement.expression, given: failing))
        }
    }

    func failing(_ expression: Expression, given failing: (Name) -> Failing?) -> Failing {
        func read(_ inner: Expression) -> Failing {
            self.failing(inner, given: failing)
        }

        switch expression {
        case .literal, .reference, .closure:
            return .these([])

        // A cast that names a type the value did not arrive as fails, and
        // that is the one failure the runtime itself raises. The optional
        // spelling reads the same mismatch as null instead, so it raises
        // nothing.
        case let .cast(value, _, optional):
            return read(value).joined(optional ? .these([]) : .these([CastRefused.type]))

        case let .array(array):
            return array.reduce(Failing.these([])) { carried, element in carried.joined(read(element)) }

        case let .record(record):
            return record.values.reduce(Failing.these([])) { carried, field in carried.joined(read(field)) }

        // Which value is called is settled at run time, so what may come out
        // of it is not knowable here.
        case .apply:
            return .unstated

        case let .call(call):
            return call.arguments.reduce(failing(call.selector) ?? .unstated) { carried, argument in
                carried.joined(read(argument))
            }

        case let .block(block):
            return self.failing(block, given: failing)

        case let .conditional(condition, then, otherwise):
            return read(condition)
                .joined(self.failing(then, given: failing))
                .joined(otherwise.map { arm in self.failing(arm, given: failing) } ?? .these([]))

        case let .loop(condition, body, _):
            return read(condition).joined(self.failing(body, given: failing))

        // The rescue is what the body's failures become: they are caught here,
        // and what is left is whatever the rescue itself may fail with.
        case let .attempt(_, rescue, _):
            return self.failing(rescue, given: failing)

        case let .leave(leave):
            return leave.value.map(read) ?? .these([])
        }
    }

    // A block answers without running when nothing it reaches is outside the
    // run. `reading` is the module's variables: a body reading one answers by
    // the run's state. `declaring` is the names the body may write; a write
    // landing anywhere else, or handing such a name in place to a call,
    // reaches the run's state the same way. `applying` is the names a slot
    // said hold a procedure with the fact, each with the positions that
    // procedure takes in place.
    func isConst(
        _ block: Block,
        declaring names: Set<Name>,
        given const: @escaping (Name) -> Bool,
        reading variables: Set<Name>,
        applying procedures: [Name: Set<Int>],
        taking asked: (Name) -> Signature?
    ) -> Bool {
        holds(
            block,
            Fact(callee: const, slot: \.isConstProcedure, unread: variables),
            declaring: names,
            applying: procedures,
            taking: asked
        )
    }

    // Whether a body writes only names it declares and calls only isolated
    // declarations. A name written that was not declared here is one the body
    // reached from outside: a module variable, or one a closure captured.
    func isIsolated(
        _ block: Block,
        declaring parameters: Set<Name>,
        given isolated: @escaping (Name) -> Bool,
        applying procedures: [Name: Set<Int>],
        taking asked: (Name) -> Signature?
    ) -> Bool {
        holds(
            block,
            Fact(callee: isolated, slot: \.isIsolatedProcedure, unread: []),
            declaring: parameters,
            applying: procedures,
            taking: asked
        )
    }

    // MARK: - Private
    // Every body starts holding the fact and is struck when something it
    // reaches does not, until nothing more is struck. Only what this call was
    // handed can be struck: what was settled before it stands in front of it
    // and reaches nothing here.
    private func strike(
        among symbols: [Symbol],
        settling holding: inout Set<Name>,
        natively: (Implementation) -> Bool,
        declaring: (Signature) -> Set<Name>,
        applying: (Signature) -> [Name: Set<Int>],
        fact: (@escaping (Name) -> Bool) -> Fact,
        taking asked: (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool
    ) {
        let own = Set(symbols.map(\.declared))

        // The body beside the names it may write and the names its own
        // declaration said hold a procedure with the fact, since applying one
        // of those is what the body is judged on.
        let bodies = symbols.reduce(
            into: [Name: (block: Block, declaring: Set<Name>, applying: [Name: Set<Int>])]()
        ) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (
                block,
                declaring(symbol.procedure.signature),
                applying(symbol.procedure.signature)
            )
        }

        holding.formUnion(
            symbols
                .filter { symbol in natively(symbol.procedure.implementation) }
                .map(\.declared)
        )

        while true {
            let settled = holding
            let walked = fact { name in own.contains(name) ? settled.contains(name) : beyond(name) }
            let struck = bodies.compactMap { name, written in
                holding.contains(name)
                    && !holds(
                        written.block,
                        walked,
                        declaring: written.declaring,
                        applying: written.applying,
                        taking: asked
                    )
                    ? name
                    : nil
            }

            guard !struck.isEmpty else { return }

            holding.subtract(struck)
        }
    }

    // A block in order. Each statement is judged against what was declared
    // before it, and a variable it introduces is declared for the rest. The
    // names a block binds are its own and leave with it, so introducing one
    // reaches nothing.
    private func holds(
        _ block: Block,
        _ fact: Fact,
        declaring names: Set<Name>,
        applying procedures: [Name: Set<Int>],
        taking asked: (Name) -> Signature?
    ) -> Bool {
        var declared = names
        var procedures = procedures

        for statement in block.body.statements {
            if case let .assignment(path)? = statement.binding, let head = path.head, !declared.contains(head) {
                return false
            }

            guard holds(statement.expression, fact, declaring: declared, applying: procedures, taking: asked) else {
                return false
            }

            if case let .variable(name, _)? = statement.binding {
                declared.insert(name)
            }

            guard let introduced = statement.binding?.introduced else { continue }

            // A name says what it holds, and a later name of the same spelling
            // is a different name, so the table is read forward.
            if let declared = statement.binding?.declared, fact.slot(declared) {
                procedures[introduced] = declared.inPlacePositions
            } else {
                procedures[introduced] = applied(statement.expression, given: procedures)
            }
        }

        return block.result.map { result in
            holds(result, fact, declaring: declared, applying: procedures, taking: asked)
        } ?? true
    }

    private func holds(
        _ expression: Expression,
        _ fact: Fact,
        declaring names: Set<Name>,
        applying procedures: [Name: Set<Int>],
        taking asked: (Name) -> Signature?
    ) -> Bool {
        func holds(_ inner: Expression) -> Bool {
            self.holds(inner, fact, declaring: names, applying: procedures, taking: asked)
        }

        func holds(_ block: Block) -> Bool {
            self.holds(block, fact, declaring: names, applying: procedures, taking: asked)
        }

        func holds(_ body: Body) -> Bool {
            holds(Block(body: body))
        }

        switch expression {
        case .literal, .closure:
            return true

        case let .reference(path):
            return path.expandingIndexReferences.allSatisfy { inner in
                inner.head.map { head in !fact.unread.contains(head) } ?? true
            }

        // Where a leave goes is inside the body, so what it reaches is what it
        // carries.
        case let .leave(leave):
            return leave.value.map(holds) ?? true

        case let .cast(value, _, _):
            return holds(value)

        case let .array(array):
            return array.allSatisfy(holds)

        case let .record(record):
            return record.values.allSatisfy(holds)

        case let .call(call):
            guard fact.callee(call.selector) else { return false }

            if let signature = asked(call.selector) {
                guard handsOwned(call.arguments, at: signature.type.inPlacePositions, declaring: names) else {
                    return false
                }
            }

            return call.arguments.allSatisfy(holds)

        // Which value is called is the run's answer, so what it reaches is
        // said by the slot the value came out of and nowhere else, and so are
        // the positions it takes in place.
        case let .apply(callee, arguments, _):
            guard let inPlace = applied(callee, given: procedures) else { return false }

            return handsOwned(arguments, at: inPlace, declaring: names) && arguments.allSatisfy(holds)

        // Which part of a construct runs is decided inside the body, so a
        // construct holds the fact as far as the parts it holds.
        case let .block(block):
            return holds(block)

        case let .conditional(condition, then, otherwise):
            return holds(condition) && holds(then) && (otherwise.map(holds) ?? true)

        case let .loop(condition, body, _):
            return holds(condition) && holds(body)

        case let .attempt(body, rescue, _):
            return holds(body) && holds(rescue)
        }
    }

    // The positions a procedure takes in place, where what this reads came
    // out of a slot that said the fact of its procedures, and nil where it
    // did not. The head is the name the slot gave, and indexing past it keeps
    // the claim, since a slot asking for an array of them says it about every
    // element. Reading a field walks into a value the slot said nothing
    // about, and so does anything that is not a name at all.
    private func applied(_ expression: Expression, given procedures: [Name: Set<Int>]) -> Set<Int>? {
        guard
            case let .reference(path) = expression,
            let head = path.head,
            path.segments.dropFirst().allSatisfy({ segment in segment.named == nil })
        else { return nil }

        return procedures[head]
    }

    // Whether every name a call hands in place at these positions is one the
    // body owns. A name handed in place is written by the callee, so the call
    // writes it here, and one the body does not own reaches the run's state.
    private func handsOwned(_ arguments: [Expression], at positions: Set<Int>, declaring names: Set<Name>) -> Bool {
        positions.allSatisfy { position in
            guard
                arguments.indices.contains(position),
                case let .reference(path) = arguments[position],
                let head = path.head
            else { return true }

            return names.contains(head)
        }
    }
}

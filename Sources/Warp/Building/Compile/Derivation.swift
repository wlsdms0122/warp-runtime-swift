//
//  Derivation.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// The facts nobody declared, worked out over a document's declarations at
// once: constness, isolation and what may fail. Each is a fixed point over
// what the bodies reach.
struct Derivation {
    // What a body is walked for. Constness and isolation are read by one walk
    // and differ only in these: which callee holds the fact, which slot says a
    // procedure it holds does, and which names a body loses it by reading. A
    // slot is judged on the type it lowers to, in the table the walk reads.
    private struct Fact {
        // MARK: - Property
        let callee: (Name) -> Bool
        let claim: (LoweredType) -> Bool
        let unread: Set<Name>
        let table: LoweredTypeTable

        // MARK: - Initializer
        // MARK: - Public
        // Whether a slot of this type says the fact of the procedure it holds.
        func isClaimed(by type: LoweredType) -> Bool {
            claim(type)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls. What is derived grows in
    // place: a document is derived against everything standing in front of
    // it, and this call only ever adds its own.
    //
    // `beyond` answers for a selector this document does not declare: the
    // row it names in the link, which carries its constness. `beside` is the
    // module's variables by the type each declared, which every body reads.
    func const(
        among symbols: [Symbol],
        deriving const: inout Set<Name>,
        reading variables: Set<Name>,
        beside declared: [Name: LoweredType],
        taking asked: @escaping (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool,
        in table: LoweredTypeTable
    ) {
        // A body may write what its signature owns: a parameter handed in
        // place is the caller's box, not the body's own.
        strike(
            among: symbols,
            deriving: &const,
            natively: { implementation in implementation.isNativelyConst != false },
            declaring: \.ownedParameters,
            fact: { given in
                Fact(callee: given, claim: \.isConstProcedure, unread: variables, table: table)
            },
            beside: declared,
            taking: asked,
            beyond: beyond,
            in: table
        )
    }

    // Which declarations touch no name another body could touch at the same
    // time. A native says so about itself; a body is read off what it writes
    // and calls.
    func isolated(
        among symbols: [Symbol],
        deriving isolated: inout Set<Name>,
        beside declared: [Name: LoweredType],
        taking asked: @escaping (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool,
        in table: LoweredTypeTable
    ) {
        strike(
            among: symbols,
            deriving: &isolated,
            natively: { implementation in implementation.isNativelyIsolated != false },
            declaring: { signature in Set(signature.names) },
            fact: { given in
                Fact(callee: given, claim: \.isIsolatedProcedure, unread: [], table: table)
            },
            beside: declared,
            taking: asked,
            beyond: beyond,
            in: table
        )
    }

    // What may come out of each of these when the work goes wrong. A native
    // says so about itself; a body is read off what it casts, calls and
    // rescues.
    //
    // Grown rather than struck out, the opposite of constness and isolation: a
    // body starts failing nothing and gains what it reaches, and a declaration
    // that says nothing about itself makes everything reaching it say nothing
    // too. Two procedures calling each other stop where nothing more is
    // added, which the finite set of declared names guarantees.
    func failing(
        among symbols: [Symbol],
        deriving failing: inout [Name: Failing],
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
                let before = failing
                let read = self.failing(block, given: { selector in own.contains(selector) ? before[selector] : beyond(selector) })

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
        self.failing(block.body, given: failing)
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

        let here = failingHere(expression, given: failing)

        switch expression {
        case .literal, .reference, .closure, .apply:
            return here

        case let .cast(value, _, _):
            return read(value).joined(here)

        case let .array(array):
            return array.reduce(here) { carried, element in carried.joined(read(element)) }

        case let .record(record):
            return record.values.reduce(here) { carried, field in carried.joined(read(field)) }

        case let .call(call):
            return call.arguments.reduce(here) { carried, argument in carried.joined(read(argument)) }

        case let .block(block):
            return self.failing(block, given: failing)

        case let .conditional(condition, then, otherwise):
            return read(condition)
                .joined(self.failing(then, given: failing))
                .joined(otherwise.map { arm in self.failing(arm, given: failing) } ?? .these([]))

        case let .loop(condition, body):
            return read(condition).joined(self.failing(body, given: failing))

        // The rescue is what the body's failures become: they are caught here,
        // and what is left is whatever the rescue itself may fail with.
        case let .attempt(_, rescue):
            return self.failing(rescue, given: failing)

        case let .leave(leave):
            return leave.value.map(read) ?? .these([])
        }
    }

    // What may come out of this node itself, apart from the nodes it holds:
    // the one judgement of where a run may fail, which `failing` gathers over
    // a tree and the type check asks where a way may end by failing.
    func failingHere(_ expression: Expression, given failing: (Name) -> Failing?) -> Failing {
        switch expression {
        // A cast that names a type the value did not arrive as fails, and
        // that is the one failure the runtime itself raises. The optional
        // spelling reads the same mismatch as null instead, so it raises
        // nothing.
        case let .cast(_, _, optional):
            return optional ? .these([]) : .these([CastRefused.type])

        // Which value is called is decided at run time, so what may come out
        // of it is not knowable here.
        case .apply:
            return .unstated

        case let .call(call):
            return failing(call.selector) ?? .unstated

        case .literal, .reference, .closure, .array, .record, .block, .conditional, .loop, .attempt, .leave:
            return .these([])
        }
    }

    // A block answers without running when nothing it reaches is outside the
    // run. `reading` is the module's variables: a body reading one answers by
    // the run's state. `declaring` is the names the body may write; a write
    // landing anywhere else, or handing such a name in place to a call,
    // reaches the run's state the same way. `bound` is the type a slot
    // declared each name in scope holds, which a call of a value is judged
    // on.
    func isConst(
        _ block: Block,
        declaring names: Set<Name>,
        given const: @escaping (Name) -> Bool,
        reading variables: Set<Name>,
        bound declared: [Name: LoweredType],
        taking asked: (Name) -> Signature?,
        in table: LoweredTypeTable
    ) -> Bool {
        holds(
            block,
            Fact(callee: const, claim: \.isConstProcedure, unread: variables, table: table),
            declaring: names,
            bound: declared,
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
        bound declared: [Name: LoweredType],
        taking asked: (Name) -> Signature?,
        in table: LoweredTypeTable
    ) -> Bool {
        holds(
            block,
            Fact(callee: isolated, claim: \.isIsolatedProcedure, unread: [], table: table),
            declaring: parameters,
            bound: declared,
            taking: asked
        )
    }

    // The type a slot declared the name a statement binds holds, which is
    // what a call of the value the name holds leans on. A name that wrote its
    // type holds that. A fixed name read from another name follows the type
    // that one was declared, through a path the way `reached` walks it. A
    // variable that wrote none holds a type the build worked out, the one its
    // writes left or the one a closure or a call took it as, and anything else
    // is such a reading too, so neither holds one.
    func declaredType(
        of binding: Statement.Binding,
        reading expression: Expression,
        given declared: (Name) -> LoweredType?,
        in table: LoweredTypeTable
    ) -> LoweredType? {
        switch binding {
        case let .constant(_, written):
            return written?.lowered(in: table) ?? reached(expression, given: declared, in: table)

        case let .variable(_, written):
            return written?.lowered(in: table)

        case .assignment:
            return nil
        }
    }

    // MARK: - Private
    // Every body starts holding the fact and is struck when something it
    // reaches does not, until nothing more is struck. Only what this call was
    // handed can be struck: what was derived before it stands in front of it
    // and reaches nothing here.
    private func strike(
        among symbols: [Symbol],
        deriving holding: inout Set<Name>,
        natively: (Implementation) -> Bool,
        declaring: (Signature) -> Set<Name>,
        fact: (@escaping (Name) -> Bool) -> Fact,
        beside variables: [Name: LoweredType],
        taking asked: (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool,
        in loweredTypes: LoweredTypeTable
    ) {
        let own = Set(symbols.map(\.declared))

        // The body beside the names it may write and the type a slot declared
        // each name before its first statement holds: the module's variables
        // and its own parameters, since a call of a value is judged on what
        // the slot it came out of says.
        let bodies = symbols.reduce(
            into: [Name: (block: Block, declaring: Set<Name>, bound: [Name: LoweredType])]()
        ) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (
                block,
                declaring(symbol.procedure.signature),
                variables.merging(
                    symbol.procedure.signature.environment(in: loweredTypes).compactMapValues(\.declaredType)
                ) { _, parameter in parameter }
            )
        }

        holding.formUnion(
            symbols
                .filter { symbol in natively(symbol.procedure.implementation) }
                .map(\.declared)
        )

        while true {
            let before = holding
            let walked = fact { name in own.contains(name) ? before.contains(name) : beyond(name) }
            let struck = bodies.compactMap { name, written in
                holding.contains(name)
                    && !holds(
                        written.block,
                        walked,
                        declaring: written.declaring,
                        bound: written.bound,
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
        bound declaredTypes: [Name: LoweredType],
        taking asked: (Name) -> Signature?
    ) -> Bool {
        var declared = names
        var declaredTypes = declaredTypes

        for statement in block.body.statements {
            if case let .assignment(path)? = statement.binding, let head = path.head, !declared.contains(head) {
                return false
            }

            guard holds(statement.expression, fact, declaring: declared, bound: declaredTypes, taking: asked) else {
                return false
            }

            if case let .variable(name, _)? = statement.binding {
                declared.insert(name)
            }

            // A later name of the same spelling is a different name, so the
            // table is read forward.
            if let binding = statement.binding, let name = binding.introduced {
                let held = declaredType(
                    of: binding,
                    reading: statement.expression,
                    given: { name in declaredTypes[name] },
                    in: fact.table
                )

                declaredTypes[name] = held
            }
        }

        return block.result.map { result in
            holds(result, fact, declaring: declared, bound: declaredTypes, taking: asked)
        } ?? true
    }

    private func holds(
        _ expression: Expression,
        _ fact: Fact,
        declaring names: Set<Name>,
        bound declared: [Name: LoweredType],
        taking asked: (Name) -> Signature?
    ) -> Bool {
        func holds(_ inner: Expression) -> Bool {
            self.holds(inner, fact, declaring: names, bound: declared, taking: asked)
        }

        func holds(_ block: Block) -> Bool {
            self.holds(block, fact, declaring: names, bound: declared, taking: asked)
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
        // the positions it takes in place. Which value that is, is read the
        // way any name is.
        case let .apply(callee, arguments):
            guard
                holds(callee),
                let reached = reached(callee, given: { name in declared[name] }, in: fact.table),
                fact.isClaimed(by: reached)
            else { return false }

            return handsOwned(arguments, at: reached.inPlacePositions, declaring: names)
                && arguments.allSatisfy(holds)

        // Which part of a construct runs is decided inside the body, so a
        // construct holds the fact as far as the parts it holds.
        case let .block(block):
            return holds(block)

        case let .conditional(condition, then, otherwise):
            return holds(condition) && holds(then) && (otherwise.map(holds) ?? true)

        case let .loop(condition, body):
            return holds(condition) && holds(body)

        case let .attempt(body, rescue):
            return holds(body) && holds(rescue)
        }
    }

    // The type this reads, as the slot it came out of says it, and nil where
    // it came out of none. The head is a name a slot declared, and the walk
    // follows that type past it: an index reads an element of an array or a
    // dictionary, and a dot reads an entry of a dictionary or a field a record
    // type declares. An array or a dictionary of them says it about every
    // element, and the value was settled against that type when it was handed
    // over, so what the type says of the part is what the slot said. A name no
    // slot declared says nothing, and anything that is not a name has no slot
    // to say anything.
    private func reached(
        _ expression: Expression,
        given declared: (Name) -> LoweredType?,
        in table: LoweredTypeTable
    ) -> LoweredType? {
        guard case let .reference(path) = expression, let head = path.head else { return nil }

        return path.segments.dropFirst().reduce(declared(head)) { reached, segment in
            switch segment {
            case .index, .indexRef:
                return reached?.element(in: table)

            case let .key(name, _):
                return reached?.dotted(name, in: table)
            }
        }
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

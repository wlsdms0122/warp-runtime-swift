//
//  Derivation.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// The facts nobody declared, worked out over every declaration at once. A
// declaration is const until its body shows otherwise, and the answer is the
// whole link's rather than any one body's.
struct Derivation {
    private struct Isolating {
        let isolated: (Name) -> Bool

        // What a callee takes, which is where a call handing something in
        // place says which slot it lands in. Asked rather than held, because
        // where a declaration's signature is read from is the caller's: the
        // link's rows once they stand, and the documents themselves before.
        let asked: (Name) -> Signature?

        func holds(_ block: Block, declared: Set<Name>, applying procedures: Set<Name>) -> Bool {
            var declared = declared
            var procedures = procedures

            return holds(block.body, declared: &declared, applying: &procedures)
                && (
                    block.result.map { result in
                        holds(result, declared: declared, applying: procedures)
                    } ?? true
                )
        }

        // A body in order. Each statement is judged against what was declared
        // before it, and a variable it introduces is declared for the rest.
        private func holds(
            _ body: [Statement],
            declared: inout Set<Name>,
            applying procedures: inout Set<Name>
        ) -> Bool {
            for statement in body {
                switch statement.binding {
                case let .assignment(path)?:
                    guard let head = path.head, declared.contains(head) else { return false }

                case .constant?, .variable?, nil:
                    break
                }

                guard holds(statement.expression, declared: declared, applying: procedures) else {
                    return false
                }

                if case let .variable(name, _)? = statement.binding {
                    declared.insert(name)
                }

                guard let introduced = statement.binding?.introduced else { continue }

                // Read forward, the way constness reads it: what a name said is
                // what stands until something else takes the spelling.
                if
                    statement.binding?.declared?.isIsolatedProcedure == true
                        || applies(statement.expression, given: procedures)
                {
                    procedures.insert(introduced)
                } else {
                    procedures.remove(introduced)
                }
            }

            return true
        }

        // Whether what this reads came out of a slot that said its procedures
        // touch no name another body could touch at the same time. The head is
        // the name the slot gave, and indexing past it keeps the claim.
        private func applies(_ expression: Expression, given procedures: Set<Name>) -> Bool {
            guard case let .reference(path) = expression, let head = path.head else { return false }

            return procedures.contains(head)
                && path.segments.dropFirst().allSatisfy { segment in segment.named == nil }
        }

        private func holds(
            _ body: [Statement],
            declared: Set<Name>,
            applying procedures: Set<Name>
        ) -> Bool {
            var inner = declared
            var applying = procedures

            return holds(body, declared: &inner, applying: &applying)
        }

        private func holds(
            _ expression: Expression,
            declared: Set<Name>,
            applying procedures: Set<Name>
        ) -> Bool {
            switch expression {
            case .literal, .reference:
                return true

            // Applying a name a slot said holds an isolated procedure runs a
            // body that writes only its own names, which is the whole of what
            // is asked here. Any other value is the run's answer and says
            // nothing.
            case let .apply(callee, arguments):
                return applies(callee, given: procedures)
                    && arguments.allSatisfy { argument in
                        holds(argument, declared: declared, applying: procedures)
                    }

            case let .cast(value, _, _):
                return holds(value, declared: declared, applying: procedures)

            case let .array(array):
                return array.allSatisfy { element in holds(element, declared: declared, applying: procedures) }

            case let .record(record):
                return record.values.allSatisfy { field in holds(field, declared: declared, applying: procedures) }

            // A closure written here is judged for its own isolation when it is
            // made; making it touches nothing.
            case .closure:
                return true

            case let .call(call):
                guard
                    isolated(call.selector),
                    let signature = asked(call.selector)
                else {
                    return false
                }

                for (parameter, argument) in zip(signature.parameters, call.arguments) where parameter.declared.isInout {
                    guard case let .reference(path) = argument, let head = path.head else { continue }

                    guard declared.contains(head) else { return false }
                }

                return call.arguments.allSatisfy { argument in holds(argument, declared: declared, applying: procedures) }

            case let .block(block):
                return holds(block, declared: declared, applying: procedures)

            case let .conditional(condition, then, otherwise):
                return holds(condition, declared: declared, applying: procedures)
                    && holds(then, declared: declared, applying: procedures)
                    && (otherwise.map { arm in holds(arm, declared: declared, applying: procedures) } ?? true)

            case let .loop(condition, body, _):
                return holds(condition, declared: declared, applying: procedures) && holds(body, declared: declared, applying: procedures)

            case let .attempt(body, rescue, _):
                return holds(body, declared: declared, applying: procedures) && holds(rescue, declared: declared, applying: procedures)

            case let .leave(leave):
                return leave.value.map { value in holds(value, declared: declared, applying: procedures) } ?? true
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls.
    //
    // Optimistic and iterated: everything with a body starts as a candidate and
    // is struck out when something it reaches is not const. Starting from "not
    // const until proven" would hold two procedures that call each other to
    // that forever, which is a fact about the algorithm rather than the code.
    // What is settled grows in place rather than being handed over and handed
    // back. A document is settled against everything standing in front of it,
    // so taking that as a value would copy the whole graph's answer once per
    // document, and this call only ever adds its own.
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
        let own = Set(symbols.map(\.declared))

        // The body beside the names its own declaration said hold a procedure
        // answering without running, since applying one of those is what the
        // body is judged on, and beside the names it may write: a parameter
        // handed in place is the caller's box, not the body's own.
        let bodies = symbols.reduce(
            into: [Name: (block: Block, declaring: Set<Name>, applying: Set<Name>)]()
        ) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (
                block,
                symbol.procedure.signature.ownedParameters,
                symbol.procedure.signature.constProcedures
            )
        }

        const.formUnion(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyConst != false }
                .map(\.declared)
        )

        // Only what this call was handed can be struck. What was settled
        // before it stands in front of it, so nothing there reaches a name
        // here, and asking after those again is asking the whole graph once
        // per document.
        while true {
            let settled = const
            let given: (Name) -> Bool = { name in own.contains(name) ? settled.contains(name) : beyond(name) }
            let struck = bodies.compactMap { name, written in
                const.contains(name)
                    && !isConst(
                        written.block,
                        declaring: written.declaring,
                        given: given,
                        reading: variables,
                        applying: written.applying,
                        taking: asked
                    ) ? name : nil
            }

            guard !struck.isEmpty else { return }

            const.subtract(struck)
        }
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
        block.body
            .reduce(Failing.these([])) { carried, statement in
                carried.joined(self.failing(statement.expression, given: failing))
            }
            .joined(block.result.map { result in self.failing(result, given: failing) } ?? .these([]))
    }

    func failing(_ body: [Statement], given failing: (Name) -> Failing?) -> Failing {
        body.reduce(Failing.these([])) { carried, statement in
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
    // run. A selector is the declared spelling it names, so the table is asked
    // by the selector as written. `reading` is the module's variables: a body
    // reading one answers by the run's state, so it does not answer without
    // running. `declaring` is the names the body may write: what its
    // signature owns and what it introduces. A write landing anywhere else, a
    // module variable, a name a closure captured, a parameter handed in place,
    // reaches the run's state the same way, and so does handing one of those
    // in place to a call.
    //
    // The names a block binds are its own. A `let` and a `var` both introduce
    // one, and neither leaves the block, so declaring either says nothing about
    // what the block reaches.
    func isConst(
        _ block: Block,
        declaring names: Set<Name>,
        given const: (Name) -> Bool,
        reading variables: Set<Name>,
        applying procedures: Set<Name>,
        taking asked: (Name) -> Signature?
    ) -> Bool {
        var declared = names
        var procedures = procedures

        for statement in block.body {
            guard
                isConst(statement.binding, declaring: declared),
                isConst(statement.expression, declaring: declared, given: const, reading: variables, applying: procedures, taking: asked)
            else { return false }

            if case let .variable(name, _)? = statement.binding {
                declared.insert(name)
            }

            guard let introduced = statement.binding?.introduced else { continue }

            // A name says what it holds, and a later name of the same spelling
            // is a different name. So the set is read forward: what a name
            // said is what stands until something else takes the spelling.
            if
                statement.binding?.declared?.isConstProcedure == true
                    || applies(statement.expression, given: procedures)
            {
                procedures.insert(introduced)
            } else {
                procedures.remove(introduced)
            }
        }

        return block.result.map { result in
            isConst(result, declaring: declared, given: const, reading: variables, applying: procedures, taking: asked)
        } ?? true
    }

    func isConst(
        _ expression: Expression,
        declaring names: Set<Name>,
        given const: (Name) -> Bool,
        reading variables: Set<Name>,
        applying procedures: Set<Name>,
        taking asked: (Name) -> Signature?
    ) -> Bool {
        func isConst(_ inner: Expression) -> Bool {
            self.isConst(inner, declaring: names, given: const, reading: variables, applying: procedures, taking: asked)
        }

        func isConst(_ statements: [Statement]) -> Bool {
            self.isConst(Block(body: statements), declaring: names, given: const, reading: variables, applying: procedures, taking: asked)
        }

        switch expression {
        case .literal, .closure:
            return true

        case let .reference(path):
            return path.expandingIndexReferences.allSatisfy { inner in
                inner.head.map { head in !variables.contains(head) } ?? true
            }

        // Leaving is how a body answers from the middle. Where it goes is
        // inside the body, so what it reaches is what it carries.
        case let .leave(leave):
            return leave.value.map(isConst) ?? true

        // Judging a value against a type reaches nothing outside itself, so a
        // cast is as const as what it reads.
        case let .cast(value, _, _):
            return isConst(value)

        case let .array(array):
            return array.allSatisfy(isConst)

        case let .record(record):
            return record.values.allSatisfy(isConst)

        // A name handed in place is written by the callee, so the call writes
        // it here: one the body does not own reaches the run's state.
        case let .call(call):
            guard const(call.selector) else { return false }

            if let signature = asked(call.selector) {
                for (parameter, argument) in zip(signature.parameters, call.arguments) where parameter.declared.isInout {
                    guard case let .reference(path) = argument, let head = path.head else { continue }

                    guard names.contains(head) else { return false }
                }
            }

            return call.arguments.allSatisfy(isConst)

        // Calling a value is settled at run time, so what it reaches is said
        // by the slot the value came out of and nowhere else. A slot asking
        // for a procedure that answers without running says it; anything else
        // says nothing, and a body applying one of those does not answer
        // without running.
        //
        // Indexing past the head keeps the claim, since a slot asking for an
        // array of them says it about every element. Anything else on the path
        // walks into a value the slot said nothing about.
        case let .apply(callee, arguments):
            return applies(callee, given: procedures)
                && arguments.allSatisfy(isConst)

        // Control flow reaches nothing on its own: which part runs is decided
        // inside the body, so a construct is as const as the parts it holds.
        case let .block(block):
            return self.isConst(block, declaring: names, given: const, reading: variables, applying: procedures, taking: asked)

        case let .conditional(condition, then, otherwise):
            return isConst(condition)
                && isConst(then)
                && (otherwise.map(isConst) ?? true)

        case let .loop(condition, body, _):
            return isConst(condition)
                && self.isConst(body, declaring: names, given: const, reading: variables, applying: procedures, taking: asked)

        case let .attempt(body, rescue, _):
            return self.isConst(body, declaring: names, given: const, reading: variables, applying: procedures, taking: asked)
                && self.isConst(rescue, declaring: names, given: const, reading: variables, applying: procedures, taking: asked)
        }
    }

    // Which declarations touch no name another body could touch at the same time.
    // Worked out the way constness is: a native says so about itself, a body starts
    // isolated, and one is struck when its body writes a name it did not declare,
    // hands one in place, calls a value, or calls a declaration that was struck,
    // until nothing more is struck.
    func isolated(
        among symbols: [Symbol],
        settling isolated: inout Set<Name>,
        taking asked: @escaping (Name) -> Signature?,
        beyond: @escaping (Name) -> Bool
    ) {
        let own = Set(symbols.map(\.declared))

        let bodies = symbols.reduce(
            into: [Name: (block: Block, declaring: Set<Name>, applying: Set<Name>)]()
        ) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (
                block,
                Set(symbol.procedure.signature.names),
                symbol.procedure.signature.isolatedProcedures
            )
        }

        isolated.formUnion(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyIsolated != false }
                .map(\.declared)
        )

        // Only what this call was handed can be struck, for the reason constness
        // reads the same way: what was settled before it stands in front of
        // it and reaches nothing here.
        while true {
            let settled = isolated
            let given: (Name) -> Bool = { name in own.contains(name) ? settled.contains(name) : beyond(name) }
            let struck = bodies.compactMap { name, body in
                isolated.contains(name)
                    && !isIsolated(
                        body.block,
                        declaring: body.declaring,
                        given: given,
                        applying: body.applying,
                        taking: asked
                    )
                    ? name
                    : nil
            }

            guard !struck.isEmpty else { return }

            isolated.subtract(struck)
        }
    }

    // Whether a body writes only names it declares and calls only isolated
    // declarations. The names it declares are read in scope order: a
    // variable is written only after the statement that introduced it, in
    // that body or one it encloses, so a name introduced inside a nested body
    // or a nested closure is nobody else's. A name written that was not
    // declared here is a name the body reached from outside: a module
    // variable, or one a closure captured.
    func isIsolated(
        _ block: Block,
        declaring parameters: Set<Name>,
        given isolated: @escaping (Name) -> Bool,
        applying procedures: Set<Name>,
        taking asked: @escaping (Name) -> Signature?
    ) -> Bool {
        Isolating(isolated: isolated, asked: asked).holds(
            block,
            declared: parameters,
            applying: procedures
        )
    }

    // MARK: - Private
    // Whether what this reads came out of a slot that said its procedures
    // answer without running. The head is the name the slot gave, and indexing
    // past it keeps the claim, since a slot asking for an array of them says
    // it about every element. Reading a field walks into a value the slot said
    // nothing about, and so does anything that is not a name at all.
    private func applies(_ expression: Expression, given procedures: Set<Name>) -> Bool {
        guard case let .reference(path) = expression, let head = path.head else { return false }

        return procedures.contains(head)
            && path.segments.dropFirst().allSatisfy { segment in segment.named == nil }
    }

    // What a binding reaches. Introducing a name reaches nothing; writing one
    // reaches whatever the path's head names, and a name the body does not
    // own is the run's state.
    private func isConst(_ binding: Statement.Binding?, declaring names: Set<Name>) -> Bool {
        guard case let .assignment(path)? = binding else { return true }

        return path.head.map { head in names.contains(head) } ?? true
    }
}

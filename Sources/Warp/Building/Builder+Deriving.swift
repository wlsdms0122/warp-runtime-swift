//
//  Builder+Deriving.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What makes an expression something the run runs rather than reads.
enum Runs: Sendable {
    case calling(Name)
    case applying
    case construct
}

// The facts nobody declared, worked out over every declaration at once. A
// declaration is const until its body shows otherwise, and the answer is the
// whole link's rather than any one body's.
extension Builder {
    // MARK: - Internal
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
    func const(
        among symbols: [Symbol],
        settling const: inout Set<Name>,
        reading variables: Set<Name>
    ) {
        // The body beside the names its own declaration said hold a procedure
        // answering without running, since applying one of those is what the
        // body is judged on.
        let bodies = symbols.reduce(into: [Name: (block: Block, applying: Set<Name>)]()) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (block, symbol.procedure.signature.constProcedures)
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
            let struck = bodies.compactMap { name, written in
                const.contains(name)
                    && !isConst(
                        written.block,
                        given: const,
                        reading: variables,
                        applying: written.applying
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
    func failing(among symbols: [Symbol], settling failing: inout [Name: Failing]) {
        for symbol in symbols {
            failing[symbol.declared] = symbol.procedure.implementation.nativelyFailing ?? .these([])
        }

        let bodies = symbols
            .compactMap { symbol in symbol.procedure.block.map { block in (symbol.declared, block) } }
            .sorted { $0.0 < $1.0 }

        while true {
            var grown = false

            for (name, block) in bodies {
                let read = self.failing(block, given: failing)

                guard read != failing[name] else { continue }

                failing[name] = read
                grown = true
            }

            guard grown else { return }
        }
    }

    // What may come out of a block: everything its statements and its result
    // may fail with.
    func failing(_ block: Block, given failing: [Name: Failing]) -> Failing {
        block.body
            .reduce(Failing.these([])) { carried, statement in
                carried.joined(self.failing(statement.expression, given: failing))
            }
            .joined(block.result.map { result in self.failing(result, given: failing) } ?? .these([]))
    }

    func failing(_ body: [Statement], given failing: [Name: Failing]) -> Failing {
        body.reduce(Failing.these([])) { carried, statement in
            carried.joined(self.failing(statement.expression, given: failing))
        }
    }

    func failing(_ expression: Expression, given failing: [Name: Failing]) -> Failing {
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
            return (failing[call.selector] ?? .unstated)
                .joined(call.receiver.map(read) ?? .these([]))
                .joined(
                    call.arguments.values.reduce(Failing.these([])) { carried, argument in
                        carried.joined(read(argument))
                    }
                )

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
    // running, and a write reaching one is the same fact from the other side.
    //
    // The names a block binds are its own. A `let` and a `var` both introduce
    // one, and neither leaves the block, so declaring either says nothing about
    // what the block reaches.
    func isConst(
        _ block: Block,
        given const: Set<Name>,
        reading variables: Set<Name>,
        applying procedures: Set<Name>
    ) -> Bool {
        var procedures = procedures

        for statement in block.body {
            guard
                isConst(statement.binding, reading: variables),
                isConst(statement.expression, given: const, reading: variables, applying: procedures)
            else { return false }

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
            isConst(result, given: const, reading: variables, applying: procedures)
        } ?? true
    }

    // Whether what this reads came out of a slot that said its procedures
    // answer without running. The head is the name the slot gave, and indexing
    // past it keeps the claim, since a slot asking for an array of them says
    // it about every element. Reading a field walks into a value the slot said
    // nothing about, and so does anything that is not a name at all.
    private func applies(_ expression: Expression, given procedures: Set<Name>) -> Bool {
        guard case let .reference(path) = expression, let head = path.head else { return false }

        return procedures.contains(head)
            && path.dropFirst().allSatisfy { segment in segment.named == nil }
    }

    // What a binding reaches. Introducing a name reaches nothing; writing one
    // reaches whatever the path's head names, and a module variable is the
    // run's state.
    private func isConst(_ binding: Statement.Binding?, reading variables: Set<Name>) -> Bool {
        guard case let .assignment(path)? = binding else { return true }

        return path.head.map { head in !variables.contains(head) } ?? true
    }

    // What an operand or a condition answers only by running, if anything. An
    // operand is data: the run reads it rather than running it, so what it may
    // hold is a literal, a name, a record, a cast and a call whose declaration
    // answers without running. Anything else is found here rather than at the
    // run.
    //
    // The module variables constness strikes a body for reading are not struck
    // here. Reading one is what reading a name is; what it costs a body is the
    // promise of answering the same thing twice, and an operand makes no such
    // promise.
    func runs(in expression: Expression, given context: TypingContext) -> Runs? {
        switch expression {
        case .literal, .reference, .closure:
            return nil

        case let .cast(value, _, _):
            return runs(in: value, given: context)

        case let .array(array):
            return array.lazy.compactMap { element in runs(in: element, given: context) }.first

        case let .record(record):
            return record.values.lazy.compactMap { field in runs(in: field, given: context) }.first

        // A contract's procedure is answered by whatever type the value turns
        // out to be, so which declaration this reaches is the run's answer and
        // its constness with it. Only a call the build resolves to a declaration
        // is judged here.
        case let .call(call):
            guard
                context.signature(of: call.selector) != nil,
                !context.const.contains(call.selector)
            else {
                return call.receiver.flatMap { receiver in runs(in: receiver, given: context) }
                    ?? call.arguments.values.lazy
                        .compactMap { argument in runs(in: argument, given: context) }.first
            }

            return .calling(call.selector)

        // Which procedure a value is, is the run's answer, so nothing here says
        // whether calling it runs.
        case .apply:
            return .applying

        case .block, .conditional, .loop, .attempt, .leave:
            return .construct
        }
    }

    func isConst(
        _ expression: Expression,
        given const: Set<Name>,
        reading variables: Set<Name>,
        applying procedures: Set<Name>
    ) -> Bool {
        func isConst(_ inner: Expression) -> Bool {
            self.isConst(inner, given: const, reading: variables, applying: procedures)
        }

        func isConst(_ statements: [Statement]) -> Bool {
            self.isConst(Block(body: statements), given: const, reading: variables, applying: procedures)
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

        case let .call(call):
            return const.contains(call.selector)
                && (call.receiver.map(isConst) ?? true)
                && call.arguments.values.allSatisfy(isConst)

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
                && arguments.values.allSatisfy(isConst)

        // Control flow reaches nothing on its own: which part runs is decided
        // inside the body, so a construct is as const as the parts it holds.
        case let .block(block):
            return self.isConst(block, given: const, reading: variables, applying: procedures)

        case let .conditional(condition, then, otherwise):
            return isConst(condition)
                && isConst(then)
                && (otherwise.map(isConst) ?? true)

        case let .loop(condition, body, _):
            return isConst(condition)
                && self.isConst(body, given: const, reading: variables, applying: procedures)

        case let .attempt(body, rescue, _):
            return self.isConst(body, given: const, reading: variables, applying: procedures)
                && self.isConst(rescue, given: const, reading: variables, applying: procedures)
        }
    }
}

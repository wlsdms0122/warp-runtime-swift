//
//  Builder+Deriving.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The facts nobody declared, worked out over every declaration at once. A
// declaration is pure until its body shows otherwise and derivable until its
// signature does, and both answers are the whole link's rather than any one
// body's, so a path may reach a word the call graph never mentions.
extension Builder {
    // MARK: - Internal
    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls.
    //
    // Optimistic and iterated: everything with a body starts as a candidate and
    // is struck out when something it reaches is not pure. Starting from "impure
    // until proven" would make two procedures that call each other permanently
    // impure, which is a fact about the algorithm rather than about the code.
    // What is settled grows in place rather than being handed over and handed
    // back. A document is settled against everything standing in front of it,
    // so taking that as a value would copy the whole graph's answer once per
    // document, and this call only ever adds its own.
    func pure(
        among symbols: [Symbol],
        settling pure: inout Set<Name>,
        reading variables: Set<Name>
    ) {
        let bodies = symbols.reduce(into: [Name: Block]()) { table, symbol in
            table[symbol.declared] = symbol.procedure.block
        }

        pure.formUnion(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyPure != false }
                .map(\.declared)
        )

        // Only what this call was handed can be struck. What was settled
        // before it stands in front of it, so nothing there reaches a name
        // here, and asking after those again is asking the whole graph once
        // per document.
        while true {
            let struck = bodies.compactMap { name, block in
                pure.contains(name) && !isPure(block, given: pure, reading: variables) ? name : nil
            }

            guard !struck.isEmpty else { return }

            pure.subtract(struck)
        }
    }

    // What may come out of each of these when the work goes wrong. A native
    // says so about itself; a body is read off what it casts, calls and
    // rescues.
    //
    // Grown rather than struck out, the opposite of purity and isolation: a
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

        // A cast that names a shape the value did not arrive as fails, and
        // that is the one failure the runtime itself raises. The optional
        // spelling reads the same mismatch as null instead, so it raises
        // nothing.
        case let .cast(value, _, optional):
            return read(value).joined(optional ? .these([]) : .these([CastRefused.word]))

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

    // A block answers without running when every part of it is something the
    // pure evaluator can answer, and every name it sends to is pure. Control
    // flow is not in that set, not because running a conditional is impure, but
    // because the surface that answers purely does not run bodies at all. A
    // selector is the declared spelling it names, so the table is asked by the
    // selector as written. `reading` is the module's variables: a body reading
    // one answers by the run's state, so it does not answer without running.
    func isPure(_ block: Block, given pure: Set<Name>, reading variables: Set<Name>) -> Bool {
        block.body.allSatisfy { statement in
            statement.binding?.isConstant != false
                && isPure(statement.expression, given: pure, reading: variables)
        }
            && (block.result.map { result in isPure(result, given: pure, reading: variables) } ?? true)
    }

    func isPure(_ expression: Expression, given pure: Set<Name>, reading variables: Set<Name>) -> Bool {
        func isPure(_ inner: Expression) -> Bool {
            self.isPure(inner, given: pure, reading: variables)
        }

        switch expression {
        case .literal, .closure:
            return true

        case let .reference(path):
            return path.expandingIndexReferences.allSatisfy { inner in
                inner.head.map { head in !variables.contains(head) } ?? true
            }

        // Leaving is not a computation, and what it does is not something the
        // pure evaluator can do: purity here means "can be answered without
        // running", and this one answers by not answering. Asking only what it
        // carries would let it through to a slot the resolver then refuses.
        case .leave:
            return false

        // Judging a value against a shape reaches nothing outside itself, so a
        // cast is as pure as what it reads.
        case let .cast(value, _, _):
            return isPure(value)

        case let .array(array):
            return array.allSatisfy(isPure)

        case let .record(record):
            return record.values.allSatisfy(isPure)

        case let .call(call):
            return pure.contains(call.selector)
                && (call.receiver.map(isPure) ?? true)
                && call.arguments.values.allSatisfy(isPure)

        // Calling a value is settled at run time, so nothing here can say what
        // it reaches. A body that does it is not answerable purely.
        case .apply:
            return false

        case .block, .conditional, .loop, .attempt:
            return false
        }
    }

    // Which declaration a path segment reaches, by the bare spelling it writes.
    // `x.count` names no module: the front end cannot know whether a trailing
    // segment is a field or a word, so this is the one name still answered at
    // run time, and the one place an ambiguity has to be refused before the run
    // rather than during it.
    //
    // A selector needs no table of its own. `std.count` is resolved by the
    // declared spelling like every other call.
    func derivable(
        for module: Module,
        declaring declared: [Name],
        pure: Set<Name>,
        reaching rows: [Name: Int],
        in table: [Linked]
    ) -> (words: [Name: Name], contested: [Name: [Name]]) {
        // What this document may walk to is what it declared and what it said
        // it imports, and nothing else in the link is something it could have
        // meant. A path names no module.
        //
        // Read off the rows, since a row is the declaration lowered and
        // whether a path may reach one is a question about the slots it
        // lowered to. A name with no row is one nothing in this link declares,
        // which the judgment that owns undeclared names refuses.
        let reachable = (declared + module.imports.sorted()).compactMap { name in
            rows[name].map { row in (declared: name, row: row) }
        }

        var held: [Name: (declared: Name, row: Int)] = [:]
        // Every declaration that contests a name, and not only that one is
        // contested. Nothing a path writes can tell them apart, so a refusal
        // names all of them. A slot holding the latest collision would keep
        // the newest two and drop whoever took the name first, so a third
        // arrival hides the declaration the other two are colliding with.
        var contested: [Name: [(declared: Name, row: Int)]] = [:]

        for reached in reachable.sorted(by: { $0.declared < $1.declared }) {
            guard pure.contains(reached.declared) else { continue }
            guard table[reached.row].isDerivable else { continue }

            // Only two words a path could both reach are ambiguous. A
            // declaration a path cannot reach shares the link but not the
            // question, so it is not competing for the name.
            if let first = held.updateValue(reached, forKey: reached.declared.unqualified) {
                contested[reached.declared.unqualified, default: [first]].append(reached)
            }
        }

        // A bare segment that could mean two declarations means neither, so
        // none of them is what it reaches. Which two is said where one is
        // written: a segment reading a field and a segment calling a word are
        // one spelling until a shape stands under it, and a document holding
        // two declarations it never steps to is answerable for nothing.
        //
        // In the order the caller handed the modules over, which is the order
        // every collision refusal is read in: the second is the one that could
        // not be added.
        return (
            words: held.filter { word, _ in contested[word] == nil }
                .mapValues { reached in reached.declared },
            contested: contested.mapValues { declarations in
                declarations
                    .sorted { one, other in table[one.row].origin < table[other.row].origin }
                    .map(\.declared)
            }
        )
    }
}
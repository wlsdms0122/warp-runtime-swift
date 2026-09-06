//
//  Linker+Deriving.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The facts nobody declared, worked out over every declaration at once. A
// declaration is pure until its body shows otherwise and derivable until its
// signature does, and both answers are the whole link's rather than any one
// body's, so a path may reach a word the call graph never mentions.
extension Linker {
    // MARK: - Internal
    // Which of these answer without running. A native says so about itself; a
    // body cannot, so it is read off what it calls.
    //
    // Optimistic and iterated: everything with a body starts as a candidate and
    // is struck out when something it reaches is not pure. Starting from "impure
    // until proven" would make two procedures that call each other permanently
    // impure, which is a fact about the algorithm rather than about the code.
    func pure(among symbols: [Symbol], reading variables: [Int: Set<Name>]) -> Set<Name> {
        let bodies = symbols.reduce(into: [Name: (Block, Set<Name>)]()) { table, symbol in
            guard let block = symbol.procedure.block else { return }

            table[symbol.declared] = (block, variables[symbol.origin] ?? [])
        }

        var pure = Set(
            symbols
                .filter { symbol in symbol.procedure.implementation.isNativelyPure != false }
                .map(\.declared)
        )

        while true {
            let struck = pure.filter { name in
                guard let (block, reading) = bodies[name] else { return false }

                return !isPure(block, given: pure, reading: reading)
            }

            guard !struck.isEmpty else { return pure }

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
    func failing(among symbols: [Symbol]) -> [Name: Failing] {
        var failing = symbols.reduce(into: [Name: Failing]()) { table, symbol in
            table[symbol.declared] = symbol.procedure.implementation.nativelyFailing ?? .these([])
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

            guard grown else { return failing }
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

    // What can be answered without running, under every name something may look
    // it up by. Two names, because there are two ways to reach one:
    //
    //   `std.count` . A selector, resolved at link like any other
    //   `count`     . A path segment. `x.count` names no module, because the
    //                  front end cannot know whether a trailing segment is a
    //                  field or a word, so this is the one name still answered
    //                  at run time, and the one place an ambiguity has to be
    //                  refused before the run rather than during it.
    //
    // Built from every declaration rather than the reached ones: a path names a
    // word the call graph never mentions, so reachability is the wrong question.
    func derivable(
        among symbols: [Symbol],
        pure: Set<Name>,
        answering contracts: Set<Name>,
        reaching derivable: Set<Name>
    ) throws -> (selectors: [Name: Symbol], words: [Name: Symbol]) {
        var selectors: [Name: Symbol] = [:]
        var words: [Name: Symbol] = [:]
        // Every declaration that contests a name, and not only that one is
        // contested. Nothing a path writes can tell them apart, so the fix is
        // on a declaration, which makes all of them something a reader has to
        // be able to reach. A slot holding the latest collision would keep the
        // newest two and drop whoever took the name first, so a third arrival
        // hides the declaration the other two are colliding with.
        var contested: [Name: [Symbol]] = [:]

        // Two tables, because a name answers two different questions. What a
        // selector reaches, and what a bare spelling a path writes may call.
        // One table held both and let a declaration whose declared spelling
        // matched another's bare last segment quietly answer the wrong
        // question. Symbols rather than procedures, because the bodies are
        // still to be read: the caller reads them through the same judgment
        // every reached body takes.
        for symbol in symbols.sorted(by: { $0.declared < $1.declared }) {
            guard pure.contains(symbol.declared) else { continue }

            selectors[symbol.declared] = symbol

            guard derivable.contains(symbol.declared) else { continue }

            // A declaration that answers a contract's word is reached through
            // the contract and not by a bare spelling. Two types answering one
            // word is the ordinary case, and a bare segment cannot say which
            // of them is meant, which is the very thing this table refuses.
            // The contract is the spelling that tells them apart.
            guard !contracts.contains(symbol.declared) else { continue }

            let bare = symbol.declared.unqualified

            // Only two words a path could both reach are ambiguous. A
            // declaration a path cannot reach shares the link but not the
            // question, so it is not competing for the name.
            if let first = words.updateValue(symbol, forKey: bare) {
                contested[bare, default: [first]].append(symbol)
            }
        }

        // The place is one declaration and the sentence names every contested
        // word, so the name that is walked to is picked in sorted order. The
        // order a dictionary hands its keys back is seeded per process, and
        // which declaration an author is sent to would change between runs.
        //
        // The second is what is walked to, the way it is wherever two
        // declarations collide. A name reaches this table only by colliding,
        // so there are always at least two.
        if let (word, declarations) = contested.min(by: { one, other in one.key < other.key }) {
            // In the order the caller handed the modules over, which is the
            // order every collision refusal is read in: the second is the one
            // that could not be added. Gathered in name order above, because
            // that is the order the tables are built in, so the two are sorted
            // apart here rather than one being made to serve for both.
            let ranked = declarations.sorted { one, other in one.origin < other.origin }

            throw LinkError(
                "\(contested.keys.sorted().map(\.spelling).joined(separator: ", ")) is declared by more"
                    + " than one module as something a path may reach. '\(word)' by"
                    + " \(ranked.map(\.declared.spelling).joined(separator: ", "))."
                    + " A path segment names no module, so there is no spelling that"
                    + " would tell them apart",
                at: ranked[1].place
            )
        }

        return (selectors, words)
    }
}

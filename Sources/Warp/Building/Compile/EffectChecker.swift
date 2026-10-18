//
//  EffectChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What a lowered row reaches, read against what its declaration says: whether
// it answers without running, whether it touches no name another body could
// touch at once, and what may come out of it when the work goes wrong. Every
// callee is read by its own declaration, and a row is read the same wherever
// it came from: a compile reads the rows it lowered, and a lay or a link the
// rows every document it lays brought.
struct EffectChecker {
    // What a body is walked for. Constness and isolation are read by one walk
    // and differ only in these: which declaration holds the fact, which
    // written type says a value called does, which slots a body loses it by
    // reading or writing, and the word a refusal says.
    private struct Fact {
        // MARK: - Property
        let held: (Signature) -> Bool
        let claim: (LoweredType) -> Bool
        let unread: Set<Int>
        let unowned: Set<Int>
        let word: String

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // A row read once for each set of module variables a body that makes it
    // fills it with.
    private struct Reading: Hashable {
        // MARK: - Property
        let row: Int
        let taken: Set<Int>

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    private let table: [Linked]
    private let resolving: Resolving
    private let contractProcedures: [Name: LoweredContractProcedure]

    // MARK: - Initializer
    init(table: [Linked], resolving: Resolving, contractProcedures: [Name: LoweredContractProcedure]) {
        self.table = table
        self.resolving = resolving
        self.contractProcedures = contractProcedures
    }

    // MARK: - Public
    // Every row among these held to what its declaration says, a refusal
    // standing where `place` says the row does.
    //
    // A closure takes what it reads outside itself from the body that makes
    // it, so it is read where that body makes it, knowing which of what it
    // takes is a module variable, once for each such reading. A closure no
    // body makes, one a constant's value holds, is read with what its own
    // frame says.
    func check(_ rows: [Int], at place: (Linked) -> Place) throws {
        var checked = Set<Reading>()
        var made = Set<Int>()

        for row in rows where table[row].closure == nil {
            try check(row, taking: [], at: place, checked: &checked, made: &made)
        }

        for row in rows where !made.contains(row) {
            try check(row, taking: [], at: place, checked: &checked, made: &made)
        }
    }

    // MARK: - Private
    // One row, and the closures its body makes. `taken` is the slots a
    // closure filled from a module variable of the body that made it.
    private func check(
        _ row: Int,
        taking taken: Set<Int>,
        at place: (Linked) -> Place,
        checked: inout Set<Reading>,
        made: inout Set<Int>
    ) throws {
        guard checked.insert(Reading(row: row, taken: taken)).inserted else { return }

        let linked = table[row]

        switch linked.implementation {
        case let .body(body, frame):
            let variables = taken.union(frame.variables.map(\.slot))

            if let reason = refusal(of: body, framed: frame, reading: variables, declared: linked.signature, of: linked.origin) {
                throw BuildError("'\(linked.rendered)' \(reason)", at: place(linked))
            }

            for (number, captures) in closures(made: body) {
                guard let closure = resolving.row(number, from: linked.origin) else { continue }

                made.insert(closure)

                let filled = Set(captures.filter { outer, _ in variables.contains(outer) }.map { _, inner in inner })

                try check(closure, taking: filled, at: place, checked: &checked, made: &made)
            }

        case let .native(_, sends):
            if let reason = refusal(of: sends, declared: linked.signature, of: linked.origin) {
                throw BuildError("'\(linked.rendered)' \(reason)", at: place(linked).part(.imports))
            }
        }
    }

    // What a procedure the host answers sends is what it reaches, so each
    // send's declaration holds what this one declares.
    private func refusal(of sends: [Sent], declared signature: Signature, of origin: Int) -> String? {
        for sent in sends {
            guard let row = resolving.row(sent.row, from: origin) else { continue }

            let callee = table[row]

            if signature.constness == .const, callee.signature.constness != .const {
                return "is declared const, and it sends '\(callee.rendered)', which is not declared const"
            }

            if signature.isolation == .isolated, callee.signature.isolation != .isolated {
                return "is declared isolated, and it sends '\(callee.rendered)', which is not declared isolated"
            }
        }

        return nil
    }

    // The closures a body makes: which row each is, and which of the body's
    // slots fill which of its own.
    private func closures(made body: LoweredBody) -> [(number: Int, captures: [(Int, Int)])] {
        var made: [(number: Int, captures: [(Int, Int)])] = []

        body.walk { node in
            if case let .operation(.closure(number, captures)) = node { made.append((number, captures)) }

            return true
        }

        return made
    }

    // What a body does beyond what its declaration says, or nil where it
    // keeps to it: one declared const reaches outside the run, one declared
    // isolated touches what another body could touch at once, or one may
    // fail with more than its declaration names. A slot a closure fills from
    // what it took is not the body's own, nor is a module variable's, and a
    // const body does not own what a caller hands it in place either.
    private func refusal(
        of body: LoweredBody,
        framed frame: Frame,
        reading variables: Set<Int>,
        declared signature: Signature,
        of origin: Int
    ) -> String? {
        let outside = variables.union(frame.captures)
        let inPlace = Set(signature.type.inPlacePositions.map { position in frame.parameters[position] })

        func name(_ slot: Int) -> String {
            frame.names[slot].spelling
        }

        if signature.constness == .const {
            let fact = Fact(
                held: { signature in signature.constness == .const },
                claim: \.isConstProcedure,
                unread: variables,
                unowned: outside.union(inPlace),
                word: "const"
            )

            if let broken = breaking(body, fact, naming: name, of: origin) {
                return "is declared const, and \(broken)"
            }
        }

        if signature.isolation == .isolated {
            let fact = Fact(
                held: { signature in signature.isolation == .isolated },
                claim: \.isIsolatedProcedure,
                unread: [],
                unowned: outside,
                word: "isolated"
            )

            if let broken = breaking(body, fact, naming: name, of: origin) {
                return "is declared isolated, and \(broken)"
            }
        }

        let failing = self.failing(body, of: origin)

        guard failing.fails(within: signature.failing) else {
            return "may fail with \(failing.rendered), and its declaration says \(signature.failing.rendered)"
        }

        return nil
    }

    // What a body reaches that the fact does not allow, or nil where it keeps
    // to it. Which part of a construct runs is decided inside the body, so a
    // construct holds the fact as far as the parts it holds.
    private func breaking(
        _ body: LoweredBody,
        _ fact: Fact,
        naming name: (Int) -> String,
        of origin: Int
    ) -> String? {
        var broken: String?

        func finding(_ reason: String) -> Bool {
            broken = reason

            return false
        }

        func read(_ address: Address) -> String? {
            if fact.unread.contains(address.slot) { return "it reads the module variable '\(name(address.slot))'" }

            for case let .at(inner, _) in address.steps {
                if let reached = read(inner) { return reached }
            }

            return nil
        }

        func handing(_ places: [Address], to callee: String) -> String? {
            for address in places {
                guard !fact.unowned.contains(address.slot) else {
                    return "it hands '\(name(address.slot))', which it does not declare, in place to \(callee)"
                }

                if let reached = read(address) { return reached }
            }

            return nil
        }

        body.walk { node in
            switch node {
            case let .instruction(instruction):
                guard case let .assign(address)? = instruction.binding else { return true }

                broken = fact.unowned.contains(address.slot)
                    ? "it writes '\(name(address.slot))', which it does not declare"
                    : read(address)

            case let .operation(.local(address)):
                broken = read(address)

            case let .operation(.call(call)):
                let callee = resolving.row(call.procedure, from: origin).map { row in table[row] }

                guard let callee, fact.held(callee.signature) else {
                    return finding("it calls '\(callee?.rendered ?? "[\(call.procedure)]")', which is not declared \(fact.word)")
                }

                broken = handing(call.handed.map(\.address), to: "'\(callee.rendered)'")

            case let .operation(.dispatch(dispatch)):
                let selector = dispatch.procedure.spelled(under: dispatch.contract)

                guard let asked = contractProcedures[selector], fact.held(asked.signature) else {
                    return finding("it calls '\(selector)', which is not declared \(fact.word)")
                }

                // A call through a contract keeps every path it hands as a
                // place. What the contract's procedure takes in place is
                // handed, since every row answering it takes in place where
                // the contract says; the rest is read.
                let inPlace = asked.signature.type.inPlacePositions

                for (position, argument) in dispatch.arguments.enumerated() {
                    guard case let .reference(address) = argument else { continue }

                    broken = inPlace.contains(position + 1)
                        ? handing([address], to: "'\(selector)'")
                        : read(address)

                    if broken != nil { break }
                }

            case let .operation(.apply(_, arguments, declared)):
                guard let declared, fact.claim(declared) else {
                    return finding("it calls a value nothing written says is \(fact.word)")
                }

                broken = handing(places(arguments), to: "a value it calls")

            case .operation:
                break
            }

            return broken == nil
        }

        return broken
    }

    // What may come out of a body: everything its instructions and its result
    // may fail with. An attempt catches what its body may fail with, and what
    // is left is whatever its rescue may fail with.
    private func failing(_ body: LoweredBody, of origin: Int) -> Failing {
        var failing = Failing.these([])

        for instruction in body.instructions {
            failing = failing.joined(self.failing(instruction.code, of: origin))
        }

        guard let result = body.result else { return failing }

        return failing.joined(self.failing(result, of: origin))
    }

    private func failing(_ instructions: [Instruction], of origin: Int) -> Failing {
        failing(LoweredBody(instructions: instructions, result: nil), of: origin)
    }

    private func failing(_ operation: Operation, of origin: Int) -> Failing {
        func failing(_ parts: [Operation]) -> Failing {
            var failing = Failing.these([])

            for part in parts {
                failing = failing.joined(self.failing(part, of: origin))
            }

            return failing
        }

        switch operation {
        case .literal, .local, .closure:
            return .these([])

        case let .array(elements):
            return failing(elements)

        case let .struct(held):
            return failing(held.fields)

        case let .dictionary(entries):
            return failing(entries.flatMap { entry in [entry.key, entry.value] })

        // Which value is called is decided at run time, so what may come out
        // of it is what the type written for it says, and anything where
        // nothing was written.
        case let .apply(callee, arguments, declared):
            return failing([callee] + values(arguments)).joined(declared?.procedureFailing ?? .anything)

        // A cast that names a type the value did not arrive as fails, and
        // that is the one failure the runtime itself raises. The optional
        // spelling reads the same mismatch as null instead, so it raises
        // nothing.
        case let .cast(read, _, optional):
            return failing([read]).joined(optional ? .these([]) : .these([CastRefused.type]))

        case let .conditional(condition, then, otherwise):
            return failing([condition])
                .joined(self.failing(then, of: origin))
                .joined(self.failing(otherwise ?? [], of: origin))

        case let .loop(condition, body, _):
            return failing([condition]).joined(self.failing(body, of: origin))

        case let .attempt(_, rescue, _):
            return self.failing(rescue, of: origin)

        case let .call(call):
            let callee = resolving.row(call.procedure, from: origin).map { row in table[row].signature.failing }

            return failing(call.arguments.compactMap { argument in argument }).joined(callee ?? .anything)

        case let .dispatch(dispatch):
            let asked = contractProcedures[dispatch.procedure.spelled(under: dispatch.contract)]?.signature.failing

            return failing([dispatch.first] + values(dispatch.arguments)).joined(asked ?? .anything)

        case let .leave(_, _, read):
            return failing(read.map { read in [read] } ?? [])
        }
    }

    // The arguments read as values, and the places handed in place.
    private func values(_ arguments: [Argument]) -> [Operation] {
        arguments.compactMap { argument in
            guard case let .value(operation) = argument else { return nil }

            return operation
        }
    }

    private func places(_ arguments: [Argument]) -> [Address] {
        arguments.compactMap { argument in
            guard case let .reference(address) = argument else { return nil }

            return address
        }
    }
}

//
//  EffectChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What a lowered body reaches, read against what its declaration says: whether
// it answers without running, whether it touches no name another body could
// touch at once, and what may come out of it when the work goes wrong. Every
// callee is read by its own declaration, so one row is read alone, and a row
// is read the same wherever it came from: a compile reads the rows it lowered,
// and a link the rows every document it lays brought.
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

    private struct Refusal: Error {
        // MARK: - Property
        let reason: String

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
    // Every written body among these rows held to what its declaration says,
    // in the document `documents` names at its origin.
    //
    // A closure takes what it reads outside itself from the body that makes
    // it, so it is read where that body makes it, knowing which of what it
    // takes is a module variable. A closure no body makes, one a constant's
    // value holds, takes nothing and is read alone.
    func check(_ rows: some Sequence<Int>, in documents: [Place.Document]) throws {
        var checked = Set<Int>()

        for row in rows where table[row].closure == nil {
            try check(row, reading: nil, in: documents, checked: &checked)
        }

        for row in rows {
            try check(row, reading: [], in: documents, checked: &checked)
        }
    }

    // MARK: - Private
    // One row, and the closures its body makes. `variables` is the slots
    // holding a module variable, nil for a declaration's own, which its frame
    // says.
    private func check(
        _ row: Int,
        reading variables: Set<Int>?,
        in documents: [Place.Document],
        checked: inout Set<Int>
    ) throws {
        guard checked.insert(row).inserted, case let .body(body, frame) = table[row].implementation else { return }

        let linked = table[row]
        let variables = variables ?? Set(frame.variables.map(\.slot))

        do throws(Refusal) {
            try check(body, framed: frame, reading: variables, declared: linked.signature, of: linked.origin)
        } catch {
            let place: Place = switch linked.closure?.by {
            case .binding?: Place(in: documents[linked.origin])
            case .procedure?, nil: .procedure(linked.label.spelling, in: documents[linked.origin])
            }

            throw BuildError("'\(linked.rendered)' \(error.reason)", at: place)
        }

        var made: [(number: Int, captures: [(Int, Int)])] = []

        body.walk { node in
            if case let .operation(.closure(number, captures)) = node { made.append((number, captures)) }

            return true
        }

        for (number, captures) in made {
            guard let closure = resolving.row(number, from: linked.origin) else { continue }

            let taken = Set(captures.filter { outer, _ in variables.contains(outer) }.map { _, inner in inner })

            try check(closure, reading: taken, in: documents, checked: &checked)
        }
    }

    // A body declared const reaches outside the run, one declared isolated
    // touches what another body could touch at once, or one may fail with
    // more than its declaration names. A slot a closure fills from what it
    // took is not the body's own, nor is a module variable's, and a const
    // body does not own what a caller hands it in place either.
    private func check(
        _ body: LoweredBody,
        framed frame: Frame,
        reading variables: Set<Int>,
        declared signature: Signature,
        of origin: Int
    ) throws(Refusal) {
        let outside = variables.union(frame.captures)
        let inPlace = Set(signature.type.inPlacePositions.map { position in frame.parameters[position] })

        func name(_ slot: Int) -> String {
            frame.names.indices.contains(slot) ? frame.names[slot].spelling : "[\(slot)]"
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
                throw Refusal(reason: "is declared const, and \(broken)")
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
                throw Refusal(reason: "is declared isolated, and \(broken)")
            }
        }

        let failing = try self.failing(body, of: origin)

        guard failing.fails(within: signature.failing) else {
            throw Refusal(reason: "may fail with \(failing.rendered), and its declaration says \(signature.failing.rendered)")
        }
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
                // place, since which row takes one in place is the row's to
                // say. What the contract's procedure takes in place is
                // handed; the rest is read.
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
    private func failing(_ body: LoweredBody, of origin: Int) throws(Refusal) -> Failing {
        var failing = Failing.these([])

        for instruction in body.instructions {
            failing = failing.joined(try self.failing(instruction.code, of: origin))
        }

        guard let result = body.result else { return failing }

        return failing.joined(try self.failing(result, of: origin))
    }

    private func failing(_ instructions: [Instruction], of origin: Int) throws(Refusal) -> Failing {
        try failing(LoweredBody(instructions: instructions, result: nil), of: origin)
    }

    private func failing(_ operation: Operation, of origin: Int) throws(Refusal) -> Failing {
        func failing(_ parts: [Operation]) throws(Refusal) -> Failing {
            var failing = Failing.these([])

            for part in parts {
                failing = failing.joined(try self.failing(part, of: origin))
            }

            return failing
        }

        switch operation {
        case .literal, .local, .closure:
            return .these([])

        case let .array(elements):
            return try failing(elements)

        case let .struct(held):
            return try failing(held.fields)

        case let .dictionary(entries):
            return try failing(entries.flatMap { entry in [entry.key, entry.value] })

        // Which value is called is decided at run time, so what may come out
        // of it is what the type written for it says, and anything where
        // nothing was written.
        case let .apply(callee, arguments, declared):
            return try failing([callee] + values(arguments)).joined(declared?.procedureFailing ?? .anything)

        // A cast that names a type the value did not arrive as fails, and
        // that is the one failure the runtime itself raises. The optional
        // spelling reads the same mismatch as null instead, so it raises
        // nothing.
        case let .cast(read, _, optional):
            return try failing([read]).joined(optional ? .these([]) : .these([CastRefused.type]))

        case let .conditional(condition, then, otherwise):
            return try failing([condition])
                .joined(try self.failing(then, of: origin))
                .joined(try self.failing(otherwise ?? [], of: origin))

        case let .loop(condition, body, _):
            return try failing([condition]).joined(try self.failing(body, of: origin))

        // What the rescue is there for. A body nothing can fail out of leaves
        // it a body no run reaches, and the author wrote it expecting
        // otherwise.
        case let .attempt(body, rescue, _):
            guard !(try self.failing(body, of: origin)).failsNothing else {
                throw Refusal(
                    reason: "attempts a body that cannot fail, so its rescue is a body"
                        + " no run reaches. What a rescue catches is what the"
                        + " body casts and calls, and this one casts and calls"
                        + " nothing that fails"
                )
            }

            return try self.failing(rescue, of: origin)

        case let .call(call):
            let callee = resolving.row(call.procedure, from: origin).map { row in table[row].signature.failing }

            return try failing(call.arguments.compactMap { argument in argument }).joined(callee ?? .anything)

        case let .dispatch(dispatch):
            let asked = contractProcedures[dispatch.procedure.spelled(under: dispatch.contract)]?.signature.failing

            return try failing([dispatch.first] + values(dispatch.arguments)).joined(asked ?? .anything)

        case let .leave(_, _, read):
            return try failing(read.map { read in [read] } ?? [])
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

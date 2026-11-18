//
//  PlacedCall.swift
//  Warp
//
//  Created by JSilver on 10/23/26.
//

import Foundation

// A call placed against the row it reaches. Arguments stand at the callee's
// slots, nil where a hold stands instead or where a dispatch hands what it
// read. A parameter handed in place takes the caller's hold: the slot holding
// it and the path below it. The build held every argument to the slot it
// lands in, so the run judges none.
struct PlacedCall: Sendable {
    struct Handed: Sendable {
        // MARK: - Property
        let position: Int
        let address: Address

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    let procedure: Int
    let arguments: [Operation?]
    let handed: [Handed]

    // MARK: - Initializer
    // A call whose parts were read apart, from an object. What is handed in
    // place stands at a position this call writes no argument at, and a run
    // writes it there without asking how many there are. The lowering writes
    // an argument at every other position and the positions handed
    // ascending, so one call is one writing.
    init(procedure: Int, arguments: [Operation?], handing handed: [Handed]) throws {
        guard handed.map(\.position) == arguments.indices.filter({ position in arguments[position] == nil }) else {
            throw ObjectRefused(
                "a call hands in place at other positions than the ones it writes no argument at,"
                    + " ascending"
            )
        }

        self.init(procedure: procedure, arguments: arguments, handed: handed)
    }

    init(procedure: Int, arguments: [Operation?], handed: [Handed]) {
        self.procedure = procedure
        self.arguments = arguments
        self.handed = handed
    }

    // An argument list placed against the callee that takes it: every argument
    // at its slot, a slot taking one in place holding the place instead, and a
    // literal settled to the slot it lands in.
    //
    // One rule, whether the callee is the one the call named or one of the
    // members the link found satisfying a contract's procedure. A call through
    // a contract is placed against every type conforming to it and the run picks
    // one by the type that fills `Self`, so these are `picked`. A literal one of them refuses
    // stands at a `Self` the contract writes, which the first argument and
    // the literal fill as one type at the build, so that row is one the run
    // never picks for this call, and the literal is left there as written.
    init(
        handing written: [Argument],
        to callee: Linked,
        row: Int,
        picked: Bool = false,
        in loweredTypes: LoweredTypeTable,
        at place: Place
    ) throws {
        guard written.count == callee.slots.count else {
            throw BuildError.unjudged(
                "\(written.count) arguments to '\(callee.rendered)', which takes \(callee.slots.count)",
                at: place
            )
        }

        var placed: [Operation?] = []
        var handed: [Handed] = []

        placed.reserveCapacity(callee.slots.count)

        for (position, slot) in callee.slots.enumerated() {
            let given = written[position]

            if case .inout = slot.type {
                guard case let .reference(address) = given else {
                    throw BuildError.unjudged(
                        "'\(slot.name)' handed to '\(callee.rendered)' in place without a variable",
                        at: place
                    )
                }

                handed.append(Handed(position: position, address: address))
                placed.append(nil)

                continue
            }

            // A literal argument is a value the build knows, so the image
            // holds it as the slot takes it rather than as it was written.
            let code = given.read

            guard case let .literal(value) = code else {
                placed.append(code)

                continue
            }

            guard picked else {
                placed.append(.literal(try slot.type.settling(value, at: "input '\(slot.name)'", in: loweredTypes)))

                continue
            }

            placed.append(.literal((try? slot.type.settling(value, at: "input '\(slot.name)'", in: loweredTypes)) ?? value))
        }

        self.init(procedure: row, arguments: placed, handed: handed)
    }

    // MARK: - Public
    // The same call with every argument it writes rewritten.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> PlacedCall {
        PlacedCall(
            procedure: procedure,
            arguments: try arguments.map { argument in
                try argument.map { argument in try argument.rewritten(operation: operation, type: type) }
            },
            handed: try handed.map { handed in
                Handed(position: handed.position, address: try handed.address.rewritten(type: type))
            }
        )
    }

    // MARK: - Private
}

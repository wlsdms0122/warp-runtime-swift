//
//  CallOperation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A call as the run makes it. Arguments stand at the callee's slots, nil
// where a hold stands instead or where a dispatch hands what it read. A parameter
// handed in place takes the caller's hold: the slot holding it and the path
// below it. The build held every argument to the slot it lands in, so the run
// judges none.
struct CallOperation: Sendable {
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
    // A call whose parts were read apart, from an object. What is handed in place
    // stands at one of the positions this call fills, and a run writes it
    // there without asking how many there are. The positions stand ascending,
    // once each, as the lowering writes them, so one call is one writing.
    init(procedure: Int, arguments: [Operation?], handing handed: [Handed]) throws {
        let positions = handed.map(\.position)

        guard
            zip(positions, positions.dropFirst()).allSatisfy({ one, next in one < next }),
            positions.allSatisfy({ position in position < arguments.count })
        else {
            throw ObjectRefused(
                "a call hands in place at positions other than ascending, once each, among the"
                    + " \(arguments.count) it fills"
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
    // literal settled to the slot it lands in. Nil where nothing was written:
    // the first one of a call through a contract, which the run hands over
    // from the reading that picked this callee.
    //
    // One rule, whether the callee is the one the call named or one of the
    // types the link found answering a contract's procedure. A call through a
    // contract is placed against every type answering it and the run picks
    // one by the value, so these are `picked`. A literal one of them refuses
    // stands at a `Self` the contract writes, which the first argument and
    // the literal fill as one type at the build, so that row is one the run
    // never picks for this call, and the literal is left there as written.
    init(
        handing written: [Argument?],
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
                guard case let .reference(address)? = given else {
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
            placed.append(try given.map { argument in
                let code = argument.read

                guard case let .literal(value) = code else { return code }

                guard picked else {
                    return .literal(try slot.checking(value, at: "input '\(slot.name)'", in: loweredTypes))
                }

                return .literal((try? slot.checking(value, at: "input '\(slot.name)'", in: loweredTypes)) ?? value)
            })
        }

        self.init(procedure: row, arguments: placed, handed: handed)
    }

    // MARK: - Public
    // The same call with every argument it writes rewritten.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> CallOperation {
        CallOperation(
            procedure: procedure,
            arguments: try arguments.map { argument in
                try argument.map { argument in try argument.rewritten(operation: operation, type: type) }
            },
            handed: handed
        )
    }

    // MARK: - Private
}

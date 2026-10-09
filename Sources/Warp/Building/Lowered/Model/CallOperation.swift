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
// below it. The run judges an argument at its slot only where the build did
// not prove it a value of the slot's type as it stands, and every argument of
// a call it picks through a contract, which the build judged against `Self`.
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

    // The positions whose argument the run judges at the row's slot, in
    // position order.
    let judged: [Int]

    // MARK: - Initializer
    // The same, where the parts were read apart. What is handed in place
    // stands at one of the positions this call fills, and a run writes it
    // there without asking how many there are. What is judged stands in
    // position order, each once.
    init(
        procedure: Int,
        arguments: [Operation?],
        judging handed: [Handed],
        judged: [Int]
    ) throws {
        guard handed.allSatisfy({ one in one.position < arguments.count }) else {
            throw ObjectRefused(
                "a call hands something in place at a position past the"
                    + " \(arguments.count) it fills"
            )
        }

        guard zip(judged, judged.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw ObjectRefused("what a call judges stands out of position order")
        }

        self.init(procedure: procedure, arguments: arguments, handed: handed, judged: judged)
    }

    init(procedure: Int, arguments: [Operation?], handed: [Handed], judged: [Int]) {
        self.procedure = procedure
        self.arguments = arguments
        self.handed = handed
        self.judged = judged
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
    // one by the value, so a literal one of those types refuses is left as
    // written, `picked`, for the run to refuse where that type is the one it
    // picks. `asItIs` names the positions the build proved need no judging;
    // a call the run picks has none.
    init(
        handing written: [Argument?],
        to callee: Linked,
        row: Int,
        picked: Bool = false,
        asItIs: (Int) -> Bool = { _ in false },
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
        var judged: [Int] = []

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

            if !asItIs(position) {
                judged.append(position)
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

        self.init(procedure: row, arguments: placed, handed: handed, judged: judged)
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
            handed: handed,
            judged: judged
        )
    }

    // MARK: - Private
}

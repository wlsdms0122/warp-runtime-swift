//
//  CallOperation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A call as the run makes it. Arguments stand in the callee's parameter
// order, nil where the call wrote nothing; the receiver stands apart the way
// it is settled apart. A parameter handed in place takes the caller's hold:
// the slot holding it and the path below it.
struct CallOperation: Sendable {
    // MARK: - Property
    let procedure: Int
    let receiver: Operation?
    let arguments: [Operation?]
    let handed: [Handed]

    struct Handed: Sendable {
        let position: Int
        let address: Address
    }

    // MARK: - Initializer
    init(procedure: Int, receiver: Operation?, arguments: [Operation?], handed: [Handed]) {
        self.procedure = procedure
        self.receiver = receiver
        self.arguments = arguments
        self.handed = handed
    }

    // An argument list placed against the callee that takes it: every argument
    // at the position of the slot it fills, a slot taking one in place holding
    // the place instead, and a literal settled to the slot it lands in.
    //
    // One rule, whether the callee is the one the call named or one of the
    // types the link found answering a contract's word. The arguments are
    // asked for by name in the order the callee's slots stand, so a call the
    // author wrote lowers each one where it lands and a call through a
    // contract hands over what it lowered once.
    init(
        handing argument: (Name) throws -> Argument?,
        written: some Sequence<Name>,
        receiver: Argument?,
        to callee: Linked,
        row: Int,
        in shapes: ShapeTable,
        at place: Place
    ) throws {
        if let stray = written.first(where: { name in callee.signature.parameters[name] == nil }) {
            throw LinkError.unjudged(
                "an argument '\(stray)' that '\(callee.label)' does not declare",
                at: place
            )
        }

        var sent: Operation?
        var placed: [Operation?] = []
        var handed: [Handed] = []

        placed.reserveCapacity(callee.slots.count)

        for (position, slot) in callee.slots.enumerated() {
            let name = slot.name
            let isReceiver = name == callee.signature.receiver

            // What the call wrote under this name, and what the slot takes:
            // the receiver written in front stands under the name the callee
            // receives by.
            let written = try argument(name)
            let given = isReceiver ? receiver ?? written : written

            if case .inout = slot.shape {
                guard case let .reference(address)? = given else {
                    throw LinkError.unjudged(
                        "'\(name)' handed to '\(callee.label)' in place without a variable",
                        at: place
                    )
                }

                handed.append(Handed(position: position, address: address))
                placed.append(nil)

                continue
            }

            if isReceiver, let receiver {
                guard written == nil else {
                    throw LinkError.unjudged(
                        "'\(name)' sent to '\(callee.label)' both in front and by name",
                        at: place
                    )
                }

                sent = receiver.read
                placed.append(nil)

                continue
            }

            // A literal argument is a value the link knows, so the image
            // holds it as the slot takes it rather than as it was written.
            placed.append(try given.map { argument in
                let code = argument.read

                guard case let .literal(value) = code else { return code }

                return .literal(try slot.taking(value, in: shapes))
            })
        }

        self.init(procedure: row, receiver: sent, arguments: placed, handed: handed)
    }

    // MARK: - Public
    // MARK: - Private
}

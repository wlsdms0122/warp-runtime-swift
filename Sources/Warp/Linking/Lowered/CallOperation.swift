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

    // MARK: - Public
    // MARK: - Private
}

//
//  LoweredArm.swift
//  Warp
//
//  Created by JSilver on 11/1/26.
//

import Foundation

// What a switch runs for one case, as the run reads it: the case by its
// name, the slot each field it binds is written to, and the code it runs. A
// field the arm does not bind takes no slot.
struct LoweredArm: Sendable {
    // MARK: - Property
    let name: Name
    let binds: [Name: Int]
    let then: [Instruction]

    // MARK: - Initializer
    init(name: Name, binds: [Name: Int] = [:], then: [Instruction]) {
        self.name = name
        self.binds = binds
        self.then = then
    }

    // MARK: - Public
    // The same arm with every operation and every type in its code replaced.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> LoweredArm {
        LoweredArm(
            name: name,
            binds: binds,
            then: try then.map { instruction in try instruction.rewritten(operation: operation, type: type) }
        )
    }

    // MARK: - Private
}

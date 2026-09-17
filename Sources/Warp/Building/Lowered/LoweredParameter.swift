//
//  LoweredParameter.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Foundation

// A parameter as a lowered procedure type holds it: its name, its type
// lowered, and whether a call must fill it. The last is settled here, once,
// from the type and the declaration's default, so a boundary settling a call
// reads it rather than working it out again.
struct LoweredParameter: Equatable, Sendable {
    // MARK: - Property
    let name: Name
    let type: LoweredType
    let mustBeGiven: Bool

    // MARK: - Initializer
    init(name: Name, type: LoweredType, mustBeGiven: Bool) {
        self.name = name
        self.type = type
        self.mustBeGiven = mustBeGiven
    }

    // MARK: - Public
    // MARK: - Private
}

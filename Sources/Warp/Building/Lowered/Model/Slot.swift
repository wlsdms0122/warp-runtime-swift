//
//  Slot.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A parameter as the run reads it: what a call and a door ask of an
// argument, and nothing else. The name for a refusal and the type to settle
// against. The declaration's type is not here; its lowering is.
final class Slot: Sendable {
    // MARK: - Property
    let name: Name
    let type: LoweredType

    // MARK: - Initializer
    init(name: Name, type: LoweredType) {
        self.name = name
        self.type = type
    }

    // MARK: - Public
    // MARK: - Private
}

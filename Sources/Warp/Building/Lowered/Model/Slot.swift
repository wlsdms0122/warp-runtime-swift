//
//  Slot.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A parameter as the run reads it: what the boundary asks of an argument,
// and nothing else. The name for a refusal and the type to settle against.
// The declaration's type is not here; its lowering is.
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
    // The value settled to the declared representation. `locus` is where a
    // refusal says the value stood, in the caller's terms.
    func checking(_ value: Value, at locus: String, in table: LoweredTypeTable) throws -> Value {
        try type.checking(value, at: locus, in: table)
    }

    // MARK: - Private
}

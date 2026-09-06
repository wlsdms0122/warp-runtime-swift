//
//  Variable.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A name that can be written, held by reference so that writing it means the
// same thing everywhere the name is visible.
//
// The two halves of scoping fall out of where the reference sits rather than
// from any rule about blocks. The link gives a variable declared inside a
// block its own slot, so it does not escape the block. The box a slot points
// at is shared, so a write inside a conditional is a write the enclosing body
// sees, which is the whole reason to have variables and the one thing a plain
// binding cannot do.
final class Variable: @unchecked Sendable {
    // MARK: - Property
    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    private let lock = NSLock()
    private var stored: Value

    // MARK: - Initializer
    // The lock is not for concurrent words, whose closures cannot write a
    // variable they did not declare. It is for the reads that still cross task
    // boundaries there, so a shared box is not a data race by construction.
    init(_ value: Value) {
        self.stored = value
    }

    // MARK: - Public
    // MARK: - Private
}

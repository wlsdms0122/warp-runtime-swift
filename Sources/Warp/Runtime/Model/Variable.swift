//
//  Variable.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A name that can be written, held by reference so that a closure taking it
// with it and a procedure it is handed to in place write what the body
// declaring it reads.
final class Variable: @unchecked Sendable {
    // MARK: - Property
    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    // Not for concurrent procedures, whose closures cannot write a variable
    // they did not declare. It is for the reads that still cross task
    // boundaries there, so a shared box is not a data race by construction.
    private let lock = NSLock()
    private var stored: Value

    // MARK: - Initializer
    init(_ value: Value) {
        self.stored = value
    }

    // MARK: - Public
    // MARK: - Private
}

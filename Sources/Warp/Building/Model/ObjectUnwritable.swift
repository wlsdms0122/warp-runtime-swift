//
//  ObjectUnwritable.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// Why no object was written for a compiled document. A caller keeping
// objects reads it where a document it expected to keep has none.
public struct ObjectUnwritable: Error, Sendable {
    // MARK: - Property
    public let reason: String

    // MARK: - Initializer
    init(_ reason: String) {
        self.reason = reason
    }

    // MARK: - Public
    // MARK: - Private
}

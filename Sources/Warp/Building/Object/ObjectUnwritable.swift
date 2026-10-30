//
//  ObjectUnwritable.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// Why no object was written for a compiled document. A host keeping
// objects reads it where a document it expected to keep has none.
public struct ObjectUnwritable: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}

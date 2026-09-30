//
//  AnyCodingKey.swift
//  WarpSyntax
//
//  Created by JSilver on 8/15/26.
//

import Foundation
import Warp

// A key that accepts whatever a container actually holds, so that the keys a
// type does not declare can be seen rather than silently skipped.
//
// Public because a notation reads its own spellings: what a condition slot holds
// is the notation's type, and a reader of it opens the same containers these
// readers do. Reading a key that was never declared is the whole job there.
public struct AnyCodingKey: CodingKey {
    // MARK: - Property
    public let stringValue: String
    public let intValue: Int?

    // MARK: - Initializer
    public init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    // A position in a list, for a coding path that descended by one.
    public init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }

    // MARK: - Public
    // MARK: - Private
}

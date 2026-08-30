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
// is the notation's shape, and a reader of it opens the same containers these
// readers do. Reading a key that was never declared is the whole job there.
public struct AnyCodingKey: CodingKey {
    // MARK: - Property
    public let stringValue: String

    public var intValue: Int? { nil }

    // MARK: - Initializer
    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    public init?(intValue: Int) {
        nil
    }

    // MARK: - Public
    // MARK: - Private
}

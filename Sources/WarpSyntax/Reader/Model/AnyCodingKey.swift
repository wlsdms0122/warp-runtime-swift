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
struct AnyCodingKey: CodingKey {
    // MARK: - Property
    let stringValue: String
    let intValue: Int?

    // MARK: - Initializer
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    // A position in a list, for a coding path that descended by one.
    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }

    // MARK: - Public
    // MARK: - Private
}

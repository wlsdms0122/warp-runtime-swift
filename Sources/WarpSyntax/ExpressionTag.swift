//
//  ExpressionTag.swift
//  WarpSyntax
//
//  Created by JSilver on 9/24/26.
//

import Foundation
import Warp

// The keys a mapping where a value is wanted is an expression by, one to a
// mapping.
public enum ExpressionTag: String, CaseIterable, Sendable {
    case reference = "ref"
    case record
    case call
    case closure
    case cast = "as"
    case optionalCast = "as?"

    // MARK: - Property
    public var key: Name {
        Name(normal: rawValue)
    }

    // MARK: - Initializer
    init?(_ key: Name) {
        self.init(rawValue: key.spelling)
    }

    // MARK: - Public
    // MARK: - Private
}

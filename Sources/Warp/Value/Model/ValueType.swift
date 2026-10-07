//
//  ValueType.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// What a value is: a `Value` case, with a record and a dictionary both a
// record. This answers about a value in hand, so there is no `Any` here and
// nothing to compose. What a *declaration* says is `TypeExpression`.
public enum ValueType: String, Sendable, CaseIterable, CustomStringConvertible {
    case null
    case bool
    case int
    case double
    case string
    case bytes
    case array
    case record

    // A value that can be called.
    case procedure

    // MARK: - Property
    // Spelled as the type of the kind is.
    public var description: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

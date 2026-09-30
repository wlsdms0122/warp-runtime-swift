//
//  ValueType.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// What a value is: a `Value` case, with a record and a dictionary both a
// record. This answers about a value in hand, so there is no `any` here and
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
    public var description: String { rawValue }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

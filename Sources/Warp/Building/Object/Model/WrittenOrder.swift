//
//  WrittenOrder.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// The order an object lays down a list no name keys: by what each entry is
// written as. Kinds stand in the order of their tags; scalars by their
// values, text by its scalars, and lists element by element, a shorter one
// first where one leads the other. Such a list is written of tags, numbers,
// names and lists of them, so these are the kinds it compares; a map, a
// struct and a closure stand by their kind alone.
struct WrittenOrder: Comparable {
    // MARK: - Property
    let value: Value

    // MARK: - Initializer
    // MARK: - Public
    static func < (lhs: WrittenOrder, rhs: WrittenOrder) -> Bool {
        precedes(lhs.value, rhs.value)
    }

    static func == (lhs: WrittenOrder, rhs: WrittenOrder) -> Bool {
        !precedes(lhs.value, rhs.value) && !precedes(rhs.value, lhs.value)
    }

    // MARK: - Private
    private static func precedes(_ one: Value, _ other: Value) -> Bool {
        switch (one, other) {
        case let (.bool(mine), .bool(theirs)):
            return !mine && theirs

        case let (.int(mine), .int(theirs)):
            return mine < theirs

        case let (.double(mine), .double(theirs)):
            return mine < theirs

        case let (.string(mine), .string(theirs)):
            return mine.unicodeScalars.lexicographicallyPrecedes(theirs.unicodeScalars)

        case let (.bytes(mine), .bytes(theirs)):
            return mine.lexicographicallyPrecedes(theirs)

        case let (.array(mine), .array(theirs)):
            for (element, their) in zip(mine, theirs) {
                if precedes(element, their) { return true }
                if precedes(their, element) { return false }
            }

            return mine.count < theirs.count

        default:
            return rank(of: one) < rank(of: other)
        }
    }

    private static func rank(of value: Value) -> Int {
        let tag: ObjectLayout.ValueTag = switch value {
        case .null: .null
        case .bool: .bool
        case .int: .int
        case .double: .double
        case .string: .string
        case .bytes: .bytes
        case .array: .array
        case .struct: .struct
        case .procedure: .closure
        case .dictionary: .dictionary
        }

        return tag.rawValue
    }
}

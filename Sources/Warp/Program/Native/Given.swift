//
//  Given.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// What a run hands a computation it asks, before it is read as any one
// procedure's arguments: the values its call wrote, by position. The first two
// stand on their own, so a call writing no more than two hands them without
// making a list.
public struct Given: Sendable {
    // MARK: - Property
    @usableFromInline
    var first: Value?

    @usableFromInline
    var second: Value?

    @usableFromInline
    var rest: [Value?]

    // MARK: - Initializer
    @usableFromInline
    init(first: Value?, second: Value?, rest: [Value?]) {
        self.first = first
        self.second = second
        self.rest = rest
    }

    @usableFromInline
    init(_ values: [Value?]) {
        self.init(
            first: values.count > 0 ? values[0] : nil,
            second: values.count > 1 ? values[1] : nil,
            rest: Array(values.dropFirst(2))
        )
    }

    // MARK: - Public
    // A place handed nothing reads as null, the way a place the row does not
    // have does.
    @inlinable
    func value(at position: Int) -> Value {
        switch position {
        case 0:
            first ?? .null

        case 1:
            second ?? .null

        default:
            rest.indices.contains(position - 2) ? rest[position - 2] ?? .null : .null
        }
    }

    // The value at a position, taken out, so whoever takes it holds it alone.
    @inlinable
    mutating func take(at position: Int) -> Value {
        switch position {
        case 0:
            first.take() ?? .null

        case 1:
            second.take() ?? .null

        default:
            rest.indices.contains(position - 2) ? rest[position - 2].take() ?? .null : .null
        }
    }

    // MARK: - Private
}

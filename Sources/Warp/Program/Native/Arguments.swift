//
//  Arguments.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// What a computation reads: the arguments its call wrote, named by the
// procedure's own key.
public struct Arguments<P: NativeProcedure>: Sendable {
    // MARK: - Property
    @usableFromInline
    var given: Given

    // MARK: - Initializer
    @inlinable
    init(_ given: Given) {
        self.given = given
    }

    // MARK: - Public
    // What an argument holds: the place the key stands at, since the run
    // ordered the arguments by the declaration this key belongs to.
    @inlinable
    public subscript(key: P.Parameters) -> Value {
        given.value(at: key.position)
    }

    // What an argument holds, taken out of the arguments, so a computation
    // that writes it writes the value it was handed rather than a copy. The
    // argument reads as null after.
    @inlinable
    public mutating func take(_ key: P.Parameters) -> Value {
        given.take(at: key.position)
    }

    // MARK: - Private
}

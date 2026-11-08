//
//  Fingerprint.swift
//  Warp
//
//  Created by JSilver on 9/16/26.
//

import Foundation

// What a compiled document is, worked out from the object rather than from
// the text it was compiled from.
//
// An `Identity` says which document this was compiled from and nothing about
// what the compile produced. Two compiles of one document produce different
// results when what stands behind them differs: a constant folds through what
// other documents declare, and a call is lowered against the declaration it
// reaches. A cache keyed by the document alone would hand back an object that
// is true against something else.
//
// Deriving one is `WarpSyntax`'s, for the reason deriving an identity is: the
// result is about bytes.
public struct Fingerprint: ContentAddress, Comparable {
    // MARK: - Property
    public let bytes: [UInt8]

    // MARK: - Initializer
    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    // MARK: - Public
    // In byte order, so a list of them is written down the same way twice. What
    // an object records is a set, and a set has to leave as a sequence.
    public static func < (lhs: Fingerprint, rhs: Fingerprint) -> Bool {
        lhs.bytes.lexicographicallyPrecedes(rhs.bytes)
    }

    // MARK: - Private
}

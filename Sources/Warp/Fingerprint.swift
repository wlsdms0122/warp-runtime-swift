//
//  Fingerprint.swift
//  Warp
//
//  Created by JSilver on 9/16/26.
//

import Foundation

// What a compiled document is, worked out from the artifact rather than from
// the text it was compiled from.
//
// An `Identity` says which document this was compiled from and nothing about
// what the compile answered. Two compiles of one document answer differently
// when what stands behind them differs: what a body reaches decides purity,
// isolation and failure, and a declaration that wrote no answer is read off
// its body against the types the link laid down. A cache keyed by the document
// alone would hand back an artifact that is true against something else.
//
// A type of its own rather than an `Identity` under another name, so neither
// can be handed to the other's door. They answer different questions, and a
// cache that took one for the other would refuse nothing and be wrong quietly.
//
// Deriving one is `WarpSyntax`'s, for the reason deriving an identity is: the
// answer is about bytes, and an artifact already has exactly one writing of
// them. This type is here so that an artifact can carry one without the
// language learning how bytes are written.
public struct Fingerprint: Sendable, Equatable, Hashable, Comparable {
    // MARK: - Property
    public let bytes: [UInt8]

    // How it reads where a person sees one: the first few bytes, the way every
    // content-addressed thing is quoted in prose.
    public var short: String {
        String(rendered.prefix(12))
    }

    public var rendered: String {
        bytes.map { byte in String(format: "%02x", byte) }.joined()
    }

    // MARK: - Initializer
    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    // MARK: - Public
    // In byte order, so a list of them is written down the same way twice. What
    // an artifact records is a set, and a set has to leave as a sequence.
    public static func < (lhs: Fingerprint, rhs: Fingerprint) -> Bool {
        lhs.bytes.lexicographicallyPrecedes(rhs.bytes)
    }

    // MARK: - Private
}

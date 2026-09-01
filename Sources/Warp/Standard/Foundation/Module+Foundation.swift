//
//  Module+Foundation.swift
//  Warp
//
//  Created by JSilver on 8/23/26.
//

import Foundation

public extension Module {
    // The ground the other bundles stand on: the memberships their words are
    // bounded by, declared once where every bundle can name them. It declares
    // no procedures — what it gives a link is vocabulary, not words — and a
    // bundle whose signatures mention these needs this module in the link,
    // which is the one dependency the standard modules have.
    static let foundation = try! Module(
        name: "std",
        description: "The shared ground: what counts as a number, and what orders.",
        types: [
            // One element of bytes — a whole number a range refines, not a
            // kind of its own. Declared here so `bytes` and `array<byte>` can
            // say they are the same thing in one vocabulary.
            "byte": .byteElement
        ],
        constraints: [
            // What arithmetic ranges over.
            "Numeric": [.int, .double],
            // What may stand left and right of an ordering — numbers among
            // themselves, and strings among themselves.
            "Comparable": [.int, .double, .string]
        ],
        procedures: [:]
    )
}

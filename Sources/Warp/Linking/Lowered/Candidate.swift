//
//  Candidate.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation

// One member of a `oneOf`, read against the slot's shape once at the link.
//
// Two readings, because an argument arrives as either. A settled value with a
// scalar spelling is compared by that spelling, and a number is compared by
// worth, so a slot that names no numeric kind still matches `1` against an int,
// and `-0.0` is in a list that writes `0.0`.
struct Candidate: Sendable {
    // MARK: - Property
    // What a document wrote, and what a scalar argument's own spelling is
    // held against.
    let spelling: String

    // The number this spelling names for the slot, or nil where it names
    // none. A fraction slot reads only fraction spellings, so the link and
    // the boundary agree on which members exist.
    let numeral: Value?

    // MARK: - Initializer
    init(_ spelling: String, in shape: Shape, reading table: ShapeTable) {
        self.spelling = spelling
        self.numeral = shape.numeral(spelling, in: table)
    }

    // MARK: - Public
    // MARK: - Private
}

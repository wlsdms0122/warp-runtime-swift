//
//  InPlaceTable.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// The positions each call of a value hands a variable in place, by the place
// the call stands at. The type check writes it beside the calls it gathers,
// and lowering reads it where it lowers each call of a value. A place stands
// for one call, so a second entry for one place is a walk that named two calls
// alike, and recording it refuses rather than keeping either.
struct InPlaceTable: Sendable {
    // MARK: - Property
    private(set) var positions: [Place: [Int]] = [:]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // What the call at this place hands in place, or nil where no call of a
    // value was judged there.
    subscript(place: Place) -> [Int]? {
        positions[place]
    }

    // What the call at this place hands in place.
    mutating func record(_ handed: [Int], at place: Place) throws {
        guard positions[place] == nil else {
            throw BuildError(
                "the build named two calls of a value by one place, which is the build's own"
                    + " mistake rather than the author's",
                at: place
            )
        }

        positions[place] = handed
    }

    mutating func absorb(_ other: InPlaceTable) throws {
        for (place, handed) in other.positions {
            try record(handed, at: place)
        }
    }

    // This table with the others' entries beside its own, for a construct
    // whose parts answer at once. A part that was not walked holds none.
    func absorbing(_ others: InPlaceTable?...) throws -> InPlaceTable {
        var absorbed = self

        for case let other? in others {
            try absorbed.absorb(other)
        }

        return absorbed
    }

    // MARK: - Private
}

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
// for one call, so two entries for one place are a walk that named two calls
// alike, and absorbing them refuses rather than keeping either.
struct InPlaceTable: Sendable {
    // MARK: - Property
    private var positions: [Place: [Int]]

    // MARK: - Initializer
    init(_ positions: [Place: [Int]] = [:]) {
        self.positions = positions
    }

    // MARK: - Public
    // What the call at this place hands in place, or nil where no call of a
    // value was judged there.
    subscript(place: Place) -> [Int]? {
        positions[place]
    }

    // This table with the others' entries beside its own.
    func absorbing(_ others: InPlaceTable...) throws -> InPlaceTable {
        var absorbed = positions

        for other in others {
            for (place, handed) in other.positions where absorbed.updateValue(handed, forKey: place) != nil {
                throw BuildError(
                    "the build named two calls of a value by one place, which is the build's own"
                        + " mistake rather than the author's",
                    at: place
                )
            }
        }

        return InPlaceTable(absorbed)
    }

    // MARK: - Private
}

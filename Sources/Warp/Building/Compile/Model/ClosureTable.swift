//
//  ClosureTable.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the build derived of each closure literal, by the place the literal
// stands at. The type check writes it beside the calls it gathers, and
// lowering reads it where it lowers each closure literal into a row. A place
// stands for one literal.
struct ClosureTable: Sendable {
    // What a closure's row carries that its literal does not write.
    struct Derived: Sendable {
        // MARK: - Property
        let constness: Constness
        let isolation: Isolation
        let failing: Failing

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    private(set) var derived: [Place: Derived] = [:]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // What the build derived of the closure literal at this place, or nil
    // where none was judged there.
    subscript(place: Place) -> Derived? {
        derived[place]
    }

    // What the build derived of the closure literal at this place.
    mutating func record(_ facts: Derived, at place: Place) {
        assert(derived[place] == nil, "one place stands for one closure literal")

        derived[place] = facts
    }

    mutating func absorb(_ other: ClosureTable) {
        for (place, facts) in other.derived {
            record(facts, at: place)
        }
    }

    // This table with the others' entries beside its own, for a construct
    // whose parts answer at once. A part that was not walked holds none.
    func absorbing(_ others: ClosureTable?...) -> ClosureTable {
        var absorbed = self

        for case let other? in others {
            absorbed.absorb(other)
        }

        return absorbed
    }

    // MARK: - Private
}

//
//  JudgementTable.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the type check judged at each place that lowering reads back, by the
// place it stands at. The type check writes it beside the calls it gathers,
// and lowering reads it where it lowers what stands there. A place stands for
// one expression, so it holds one judgement.
struct JudgementTable: Sendable {
    // MARK: - Property
    private(set) var judgements: [Place: Judgement] = [:]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // What the type check judged at this place, or nil where it judged
    // nothing lowering reads.
    subscript(place: Place) -> Judgement? {
        judgements[place]
    }

    // What the type check judged at this place.
    mutating func record(_ judgement: Judgement, at place: Place) {
        assert(judgements[place] == nil, "one place stands for one expression")

        judgements[place] = judgement
    }

    mutating func absorb(_ other: JudgementTable) {
        for (place, judgement) in other.judgements {
            record(judgement, at: place)
        }
    }

    // This table with the others' entries beside its own, for a construct
    // whose parts answer at once. A part that was not walked holds none.
    func absorbing(_ others: JudgementTable?...) -> JudgementTable {
        var absorbed = self

        for case let other? in others {
            absorbed.absorb(other)
        }

        return absorbed
    }

    // MARK: - Private
}

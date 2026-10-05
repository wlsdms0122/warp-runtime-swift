//
//  JudgementTable.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the type check judged at each place that lowering reads back, by the
// place it stands at. The type check writes it beside the calls it gathers,
// reads it over a body for the hand-back proof, and lowering reads it where it
// lowers what stands there. A place stands for
// one expression, so it holds one judgement.
struct JudgementTable: Sendable {
    // MARK: - Property
    private(set) var judgements: [Place: Judgement] = [:]

    // Whether a reading of a type parameter of the body may hold what is
    // not a value of it somewhere here, which the hand-back proof reads as
    // proving nothing.
    private(set) var loosened = false

    // What a write into a box that declared nothing settles to, by the
    // statement that writes it: the type the check held the write to, where
    // the box is held to one (a variable a closure captured or a call handed
    // in place, a module variable that wrote no type) or the write goes
    // through a path. A box that declared its type settles by its slot.
    private(set) var writes: [Place: LoweredType] = [:]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // What the type check judged at this place, or nil where it judged
    // nothing lowering reads.
    subscript(place: Place) -> Judgement? {
        judgements[place]
    }

    // What the write at this statement settles to, or nil where the check
    // held it to nothing lowering reads.
    func settling(writeAt place: Place) -> LoweredType? {
        writes[place]
    }

    // What the type check judged at this place.
    mutating func record(_ judgement: Judgement, at place: Place) {
        assert(judgements[place] == nil, "one place stands for one expression")

        judgements[place] = judgement
    }

    // What the write at this statement settles to. A statement walked again
    // holds the type it was last held to.
    mutating func record(write settling: LoweredType, at place: Place) {
        writes[place] = settling
    }

    // A reading of a type parameter here may hold what is not a value of
    // it.
    mutating func loosen() {
        loosened = true
    }

    mutating func absorb(_ other: JudgementTable) {
        for (place, judgement) in other.judgements {
            record(judgement, at: place)
        }

        writes.merge(other.writes) { _, theirs in theirs }

        loosened = loosened || other.loosened
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

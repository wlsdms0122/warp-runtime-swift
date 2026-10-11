//
//  JudgementTable.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What the type check judged at each place that lowering reads back, by the
// place it stands at. The type check writes it beside the calls it gathers, and
// lowering reads it where it lowers what stands there. A place stands for one
// expression, so it holds one judgement.
struct JudgementTable: Sendable {
    // MARK: - Property
    private(set) var judgements: [Place: Judgement] = [:]

    // The name a record built at a place takes: one written where a declared
    // record is read is built as that record.
    private(set) var names: [Place: Name] = [:]

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

    // The name the record built at this place takes, or nil where it is
    // built under none.
    func name(ofRecordAt place: Place) -> Name? {
        names[place]
    }

    // The names records built at these places take.
    mutating func record(names: [Place: Name]) {
        guard !names.isEmpty else { return }

        self.names.merge(names) { _, theirs in theirs }
    }

    // The other's entries beside this table's own, the other's standing
    // where both hold a place.
    mutating func absorb(_ other: JudgementTable) {
        Self.absorb(other.judgements, into: &judgements) { _, theirs in
            assertionFailure("one place stands for one expression")

            return theirs
        }
        Self.absorb(other.names, into: &names) { _, theirs in theirs }
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
    // A table carried up through every construct holding it is inserted
    // into the larger of the two, so an entry is hashed again only where it
    // joins a larger table and not at every level it passes. `resolve` is
    // asked with this table's entry first and the other's second.
    private static func absorb<Value>(
        _ other: [Place: Value],
        into own: inout [Place: Value],
        resolve: (Value, Value) -> Value
    ) {
        guard !other.isEmpty else { return }

        guard !own.isEmpty else {
            own = other

            return
        }

        guard own.count < other.count else {
            own.merge(other, uniquingKeysWith: resolve)

            return
        }

        let smaller = own

        own = other
        own.merge(smaller) { theirs, mine in resolve(mine, theirs) }
    }
}

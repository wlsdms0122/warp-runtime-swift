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

    // The name a struct literal at a place is built under: the declared
    // struct the place it is written into reads.
    private(set) var names: [Place: Name] = [:]

    // The path a statement at a place writes, as the walk that judged where
    // the write lands placed it.
    private(set) var writes: [Place: LoweredPath] = [:]

    // What becomes of the value an expression at a place reads, where the
    // place it lands in reads it another way.
    private(set) var coercions: [Place: Coercion] = [:]

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

    // The name the struct literal at this place is built under, or nil
    // where the type check judged none there.
    func name(ofStructAt place: Place) -> Name? {
        names[place]
    }

    // The name the struct literal at this place is built under.
    mutating func record(_ name: Name, ofStructAt place: Place) {
        assert(names[place] == nil, "one place stands for one expression")

        names[place] = name
    }

    // The path the statement at this place writes, or nil where the type
    // check placed none there.
    func path(writtenAt place: Place) -> LoweredPath? {
        writes[place]
    }

    // The path the statement at this place writes.
    mutating func record(_ path: LoweredPath, writtenAt place: Place) {
        assert(writes[place] == nil, "one place stands for one statement")

        writes[place] = path
    }

    // What becomes of the value the expression at this place reads, or nil
    // where it lands as it is.
    func coercion(at place: Place) -> Coercion? {
        coercions[place]
    }

    // What becomes of the value the expression at this place reads. A body a
    // loop walks again is judged again, and the later judgement stands.
    mutating func record(_ coercion: Coercion, at place: Place) {
        coercions[place] = coercion
    }

    // The other's entries beside this table's own, the other's standing
    // where both hold a place.
    mutating func absorb(_ other: JudgementTable) {
        Self.absorb(other.judgements, into: &judgements) { _, theirs in
            assertionFailure("one place stands for one expression")

            return theirs
        }
        Self.absorb(other.names, into: &names) { _, theirs in theirs }
        Self.absorb(other.coercions, into: &coercions) { _, theirs in theirs }
        Self.absorb(other.writes, into: &writes) { _, theirs in
            assertionFailure("one place stands for one statement")

            return theirs
        }
    }

    // This table with the others' entries beside its own, for a construct
    // whose parts are judged at once. A part that was not walked holds none.
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

//
//  Substitution.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// What a call put in a declaration's type parameters, and where it put two
// things in one.
//
// A parameter read two ways has no answer, so the disagreement is kept beside
// the first reading rather than read as `any`: `any` is what a declaration
// says when it said nothing.
struct Substitution: Sendable {
    // A value that arrived where a composition stands, beside what the
    // composition holds it to, and whether the slot takes null as well.
    struct Held: Sendable {
        // MARK: - Property
        let reading: LoweredType
        let bounds: [LoweredType.Bound]
        let orNull: Bool

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // What each type parameter is read as: the join of its readings, or the
    // first where two disagree. A parameter only ever read through a join
    // that is no type it stands in is read as nothing.
    let readings: [Name: LoweredType]

    // For a parameter read two ways, the second reading. Keeping both is what
    // lets a refusal name them.
    let disagreeing: [Name: LoweredType]

    // The readings of each bounded parameter that its join is not, as they
    // were read, since the join may not say what each one was.
    let apart: [Name: [LoweredType]]

    // MARK: - Initializer
    // MARK: - Public
    // What a bounded parameter is held to its bounds as: what it is read as,
    // and each reading that does not say.
    func everyReading(of parameter: Name) -> [LoweredType] {
        (readings[parameter].map { reading in [reading] } ?? []) + apart[parameter, default: []]
    }

    // MARK: - Private
}

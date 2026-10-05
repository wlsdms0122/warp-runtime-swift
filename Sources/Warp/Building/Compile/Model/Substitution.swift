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
// A parameter read two ways has no answer, so the disagreement is held apart
// rather than read as `any`: `any` is what a declaration says when it said
// nothing.
struct Substitution: Sendable {
    // A value that arrived where a composition stands, beside the bounds it
    // is held to, and whether the slot takes null as well. Or one of two
    // readings a bounded parameter was read as, which the join of the two
    // may no longer say, held to the parameter's bounds as it was read.
    struct Held: Sendable {
        // MARK: - Property
        let reading: LoweredType
        let bounds: [LoweredType.Bound]
        let orNull: Bool

        // The bounded parameter the reading was read at, or nil where a
        // composition holds it.
        let parameter: Name?

        // MARK: - Initializer
        init(reading: LoweredType, bounds: [LoweredType.Bound], orNull: Bool, parameter: Name? = nil) {
            self.reading = reading
            self.bounds = bounds
            self.orNull = orNull
            self.parameter = parameter
        }

        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The first reading of each type parameter.
    let readings: [Name: LoweredType]

    // For a parameter read two ways, the second reading. Keeping both is what
    // lets a refusal name them.
    let disagreeing: [Name: LoweredType]

    // The readings each bounded parameter was joined from, as they were
    // read, since what they joined to may not say what each one was.
    let apart: [Name: [LoweredType]]

    // MARK: - Initializer
    // What a walk read, with what it held: the readings held at a bounded
    // parameter are the ones its join was made from.
    init(readings: [Name: LoweredType], disagreeing: [Name: LoweredType], holding: [Held]) {
        var apart: [Name: [LoweredType]] = [:]

        for held in holding {
            guard let parameter = held.parameter else { continue }

            apart[parameter, default: []].append(held.reading)
        }

        self.readings = readings
        self.disagreeing = disagreeing
        self.apart = apart
    }

    // MARK: - Public
    // MARK: - Private
}

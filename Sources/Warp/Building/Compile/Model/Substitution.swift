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
    // A value that arrived where a composition stands, beside what the
    // composition holds it to.
    struct Held: Sendable {
        // MARK: - Property
        let reading: LoweredType
        let bounds: [LoweredType.Bound]

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The first reading of each type parameter.
    let readings: [Name: LoweredType]

    // For a parameter read two ways, the second reading. Keeping both is what
    // lets a refusal name them.
    let disagreeing: [Name: LoweredType]

    // What arrived wherever a slot declared a composition, by slot. Nothing
    // fills a composition and no name ties it to another slot, so it is
    // judged where it stands rather than read.
    let holding: [(slot: Name, held: Held)]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

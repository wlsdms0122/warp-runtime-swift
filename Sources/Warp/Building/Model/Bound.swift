//
//  Bound.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// What a call put in a declaration's type parameters, and where it put two
// things in one.
//
// The second half is here rather than folded into the first because a parameter
// read two ways has no answer, and folding it to `any` would be an answer. `any`
// says "anything", which is what a declaration says when it said nothing, so a
// checker that folded a disagreement would go on as though nothing had been
// declared.
struct Bound: Sendable {
    // MARK: - Property
    // The first reading of each type parameter.
    let readings: [Name: LoweredType]

    // For a parameter read two ways, the second reading. Keeping both is what
    // lets a refusal name them.
    let disagreeing: [Name: LoweredType]

    // What arrived at each slot declared as a composition, beside what the
    // composition holds it to. Nothing fills a composition and no name ties
    // it to another slot, so it is judged slot by slot rather than read.
    let holding: [(slot: Name, reading: LoweredType, bounds: [LoweredType.Bound])]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

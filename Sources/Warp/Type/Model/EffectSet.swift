//
//  EffectSet.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// What a procedure declares of itself beside what it takes and returns:
// whether it is const, whether it touches no name another
// body could touch at once, and what may come out of it when the work goes
// wrong. A signature declares one, and a procedure type asks one of what
// stands in it.
struct EffectSet: Sendable, Equatable {
    // One of the three.
    enum Kind {
        case constness
        case isolation
        case failing
    }

    // MARK: - Property
    let constness: Constness
    let isolation: Isolation
    let failing: Failing

    // MARK: - Initializer
    init(constness: Constness, isolation: Isolation, failing: Failing) {
        self.constness = constness
        self.isolation = isolation
        self.failing = failing
    }

    // MARK: - Public
    // The first of the three in which this does more than `allowed` allows,
    // or nil where it stands where `allowed` is asked: const where const is
    // asked, isolated where isolation is, and failing within what is named.
    func exceeding(_ allowed: EffectSet) -> Kind? {
        if allowed.constness == .const, constness != .const { return .constness }

        if allowed.isolation == .isolated, isolation != .isolated { return .isolation }

        guard failing.fails(within: allowed.failing) else { return .failing }

        return nil
    }

    // MARK: - Private
}

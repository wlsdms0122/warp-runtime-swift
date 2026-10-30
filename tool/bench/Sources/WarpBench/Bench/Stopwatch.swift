//
//  Stopwatch.swift
//  WarpBench
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// How long the work took, on the one clock every figure here is read from.
struct Stopwatch {
    // MARK: - Property
    private let clock = ContinuousClock()

    // MARK: - Initializer
    // MARK: - Public
    func elapsed(_ work: () throws -> Void) rethrows -> Duration {
        let started = clock.now

        try work()

        return clock.now - started
    }

    func elapsed(_ work: () async throws -> Void) async rethrows -> Duration {
        let started = clock.now

        try await work()

        return clock.now - started
    }

    // MARK: - Private
}

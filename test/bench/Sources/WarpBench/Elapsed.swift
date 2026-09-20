//
//  Elapsed.swift
//  WarpBench
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// How long the work took, on the one clock every figure here is read from.
func elapsed(_ work: () throws -> Void) rethrows -> Duration {
    let clock = ContinuousClock()
    let started = clock.now

    try work()

    return clock.now - started
}

func elapsed(_ work: () async throws -> Void) async rethrows -> Duration {
    let clock = ContinuousClock()
    let started = clock.now

    try await work()

    return clock.now - started
}

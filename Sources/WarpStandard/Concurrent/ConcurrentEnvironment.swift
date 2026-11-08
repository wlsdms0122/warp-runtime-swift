//
//  ConcurrentEnvironment.swift
//  WarpStandard
//
//  Created by JSilver on 10/18/26.
//

import Foundation
import Warp

// A fan-out is an isolation boundary for the host as much as for the
// language: ambient state a host carries on the task (a task local holding an
// open session, say) reaches every piece at once unless it is severed or
// forked here. An environment that carries such state conforms to this, and a
// fan-out runs each piece through it.
public protocol ConcurrentEnvironment: Environment {
    func isolateConcurrentWork<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T
}

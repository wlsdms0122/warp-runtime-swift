//
//  Environment.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a host hands one run: the services its own procedures reach for, and
// whatever else only that host knows about. The language never reads it; an
// effect recognises its own environment and takes it from here.
public protocol Environment: Sendable {
    // A fan-out is an isolation boundary for the host as much as for the
    // language. Ambient state a host carries on the task (a task local
    // holding an open session, say) would otherwise reach every piece at once,
    // and siblings would share one conversation. This is where that state is
    // severed or forked. The language stays ignorant of what the state is.
    // Every environment answers it, the default running the work as it is.
    func isolateConcurrentWork<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T
}

public extension Environment {
    // Running the work as it stands. Correct for any host that carries no
    // ambient state, which is most of them.
    func isolateConcurrentWork<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        try await work()
    }
}

//
//  Location.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// Where a run stands, as the state a trace is built from: a trace already
// built, a frame entered and running no statement yet, or a statement of a
// frame running on the rounds its loops are on. Building a trace allocates
// a link per hop, so a run carries this and builds one only where a trace is
// read: a refusal leaving a statement, an observer, an effect.
enum Location: Sendable {
    case trace(Trace)
    case entered(FrameLink)
    case running(FrameLink, Site, rounds: [Int])

    // MARK: - Property
    var trace: Trace {
        switch self {
        case let .trace(trace):
            return trace

        case let .entered(link):
            return link.trace

        case let .running(link, site, rounds):
            return site.trace(under: link.trace, rounds: rounds)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

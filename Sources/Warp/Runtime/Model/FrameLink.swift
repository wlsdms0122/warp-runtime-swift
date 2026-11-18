//
//  FrameLink.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// A frame's dynamic link: where the run stood when it entered the frame, and
// the hop entering took, or none for the frame a run or a fold starts in.
// One per frame that a trace below it reads, so a statement's trace is built
// from its frame's link and nothing a run makes per statement.
final class FrameLink: Sendable {
    // MARK: - Property
    let caller: Location
    let hop: Trace.Hop?

    // The trace of the frame, running no statement yet.
    var trace: Trace {
        guard let hop else { return caller.trace }

        return caller.trace.entering(hop)
    }

    // MARK: - Initializer
    init(caller: Location, hop: Trace.Hop?) {
        self.caller = caller
        self.hop = hop
    }

    // MARK: - Public
    // MARK: - Private
}

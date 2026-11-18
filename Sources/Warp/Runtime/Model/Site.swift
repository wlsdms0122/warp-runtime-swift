//
//  Site.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// Where a statement stands in its body, worked out once where the body is
// compiled: the statement holding the list it is in, the hop a trace takes
// into it, its place in its document, and the loop whose round it runs in
// where its list is a loop's body. A run reads none of it until a trace is
// asked for.
final class Site: Sendable {
    // MARK: - Property
    let parent: Site?
    let hop: Trace.Hop
    let place: Place?

    // Which of the loops around it in its body, counted from the outermost,
    // this statement runs a round of, where the list holding it is that
    // loop's body. The round it is on is the run's to say.
    let round: Int?

    // MARK: - Initializer
    init(parent: Site?, hop: Trace.Hop, place: Place?, round: Int?) {
        self.parent = parent
        self.hop = hop
        self.place = place
        self.round = round
    }

    // MARK: - Public
    // The trace of this statement running, in a frame whose own trace is
    // `base`, the loops around it on the rounds `rounds` holds by depth.
    func trace(under base: Trace, rounds: [Int]) -> Trace {
        var trace = parent.map { parent in parent.trace(under: base, rounds: rounds) } ?? base

        if let round {
            trace = trace.appending(.round(rounds[round]))
        }

        return trace.running(hop, at: place)
    }

    // MARK: - Private
}

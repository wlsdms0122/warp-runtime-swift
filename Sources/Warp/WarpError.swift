//
//  WarpError.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// Everything this language refuses with says one sentence about why. No area
// owns that — validation, linking, the runtime and the notation reader all
// declare it — so it sits at the root beside `Language` rather than being
// filed under whichever of them is asked to keep it.
public protocol WarpError: Error, Sendable, CustomStringConvertible {
    var message: String { get }

    // Where the run was when this was refused. A sentence is written where the
    // mistake is noticed and nothing there is holding a place, so the place goes
    // on as the failure leaves the statement it happened in — and the innermost
    // one stays, because a statement further out is where the run was rather
    // than where the mistake is.
    var trace: Trace? { get }

    // Where in the document the words are. A stage that reads a program before
    // running it has this and no trace; a run has the trace and the text is
    // behind it. Two questions, so two slots — and a refusal answers whichever
    // one it is in a position to.
    var place: Place? { get }

    func tracing(_ trace: Trace) -> Self
}

public extension WarpError {
    var description: String {
        guard let whereabouts = trace?.rendered ?? place?.rendered else { return message }

        return "\(whereabouts): \(message)"
    }

    // What refuses before a run has nowhere to have been.
    var trace: Trace? { nil }

    // What refuses during a run says where the run was, and the statement it
    // was in is the text — so nothing there assembles a place a second time.
    var place: Place? { nil }

    func tracing(_ trace: Trace) -> Self { self }
}

//
//  WarpError.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// Everything this language refuses with says one sentence about why.
public protocol WarpError: Error, Sendable, CustomStringConvertible {
    var message: String { get }

    // Where the run was when this was refused. A sentence is written where the
    // mistake is noticed and nothing there is holding a place, so the place
    // goes on as the failure leaves the statement it happened in, and the
    // innermost one stays, because a statement further out is where the run was
    // rather than where the mistake is.
    var trace: Trace? { get }

    // Where in the document the words are. A stage that reads a program before
    // running it has this and no trace; a run has the trace and the text is
    // behind it. Two questions, so two slots, and a refusal fills whichever
    // one it is in a position to.
    var place: Place? { get }

    func tracing(_ trace: Trace) -> Self
}

public extension WarpError {
    var description: String {
        // Whichever of the two says something. A trace comes first where there
        // is one, since a refusal from a run is read as where the run had been.
        // A place in no document at no step says nothing and says so, which is
        // what a fragment assembled in Swift has, and then the sentence is the
        // whole message.
        guard let whereabouts = trace?.rendered ?? place.flatMap(\.rendered) else {
            return message
        }

        return "\(whereabouts): \(message)"
    }

    // What refuses before a run has nowhere to have been.
    var trace: Trace? { nil }

    // The places a run's refusal names, under WARP-72: one for each frame
    // the run stood in that was running a statement, the outermost first.
    // Empty where no frame was, and for what refuses before a run.
    var places: [Place] { trace?.places ?? [] }

    // The one spot in a document a load or a build stopped at. A run stops
    // in a frame inside other frames, and names their places instead.
    var place: Place? { nil }

    func tracing(_ trace: Trace) -> Self { self }
}

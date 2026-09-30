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

    // Where in the document the procedures are. A stage that reads a program before
    // running it has this and no trace; a run has the trace and the text is
    // behind it. Two questions, so two slots, and a refusal answers whichever
    // one it is in a position to.
    var place: Place? { get }

    func tracing(_ trace: Trace) -> Self

    // The same refusal, addressed somewhere else. A place is spelled by the
    // side reading it (the language names its own slots, a reading side names
    // the keys a document writes) so a refusal has to be able to take the
    // reading its reader is owed without losing what it is.
    //
    // The default answers with itself, for a refusal that names no place.
    func placed(_ place: Place) -> Self
}

public extension WarpError {
    var description: String {
        // Whichever of the two says something. A trace comes first where there
        // is one, since a refusal from a run is read as where the run had been.
        // A place in no document at no step says nothing and says so, which is
        // what a fragment a caller assembled has, and then the sentence is the
        // whole answer.
        guard let whereabouts = trace?.rendered ?? place.flatMap(\.rendered) else {
            return message
        }

        return "\(whereabouts): \(message)"
    }

    // What refuses before a run has nowhere to have been.
    var trace: Trace? { nil }

    // What refuses during a run says where the run was, and the statement it
    // was in is the text, so nothing there assembles a place a second time.
    var place: Place? { nil }

    func tracing(_ trace: Trace) -> Self { self }

    func placed(_ place: Place) -> Self { self }
}

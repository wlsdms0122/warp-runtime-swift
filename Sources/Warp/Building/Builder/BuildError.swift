//
//  BuildError.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Deliberately not a `RecoverableFailure`. A call that names nothing, or calls
// with arguments the callee never declared, is an author mistake. Absorbing it
// into a rescue path would hide the one class of defect building exists to find.
public struct BuildError: WarpError {
    // MARK: - Property
    public let message: String
    public let place: Place?

    // MARK: - Initializer
    // The place is stated and never defaulted, and what it says is where the
    // fix goes.
    //
    // Two modules declaring one name is two places, and the refusal is
    // addressed to the second (the declaration that cannot be added) with the
    // first named in the sentence. A build holds several documents and only the
    // host knows which file each arrived in, so a refusal that named neither
    // would send it opening all of them.
    //
    // A document and no steps is what is wrong with a document rather than with
    // anything in it: the same text handed over twice.
    public init(_ message: String, at place: Place) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> Self {
        BuildError(message, at: place)
    }

    // A body the build lowered without judging it first: what the lowering
    // cannot place is the build's own mistake rather than the author's, and
    // reads that way.
    static func unjudged(_ what: String, at place: Place) -> BuildError {
        BuildError("the build lowered \(what) without judging it", at: place)
    }

    // A spelling reached from outside the one document that may name it. Said
    // once, wherever a lookup fails on one.
    static func concealed(_ name: Name, at place: Place) -> BuildError {
        BuildError(
            "'\(name)' is private to the document that declares it, and nothing outside"
                + " that document names it",
            at: place
        )
    }

    // MARK: - Private
}

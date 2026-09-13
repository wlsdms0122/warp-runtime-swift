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
    // caller knows which file each arrived in, so a refusal that named neither
    // would send it opening all of them.
    //
    // A document and no steps is what is wrong with a document rather than with
    // anything in it: the same text handed over twice.
    //
    // Nil is for what no address is known for, said out loud rather than left
    // to a default. The entry, which is an argument to building and written in
    // no text.
    public init(_ message: String, at place: Place?) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    public func placed(_ place: Place) -> Self {
        BuildError(message, at: place)
    }

    // MARK: - Private
}

extension BuildError {
    // What a procedure that receives by no name says about a value sent to it.
    // The judging turns down a call that writes one and the run turns down a
    // send that carries one, and two spellings of a sentence are two sentences
    // before long.
    //
    // The two differ on null, and the difference is what each can see. A
    // document writing null in front of such a call wrote something that goes
    // nowhere, and the text shows it. A send carries whatever the Swift body
    // computed, where null is how being sent to nothing arrives.
    static let receivesByNoName = "declares nothing to be sent to"

    // A body the build lowered without judging it first: what the lowering
    // cannot place is the build's own mistake rather than the author's, and
    // reads that way.
    static func unjudged(_ what: String, at place: Place) -> BuildError {
        BuildError("the build lowered \(what) without judging it", at: place)
    }
}

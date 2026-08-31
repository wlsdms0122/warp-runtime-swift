//
//  LinkError.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// Deliberately not a `RecoverableFailure`. A call that names nothing, or calls
// with arguments the callee never declared, is an author mistake — absorbing it
// into a rescue path would hide the one class of defect linking exists to find.
public struct LinkError: WarpError {
    // MARK: - Property
    public let message: String
    public let place: Place?

    // MARK: - Initializer
    // The place is stated and never defaulted, and what it says is where the
    // fix goes.
    //
    // Two modules declaring one name is two places, and the refusal is
    // addressed to the second — the declaration that cannot be added — with
    // the first named in the sentence. A link holds several documents and only
    // the caller knows which file each arrived in, so a refusal that named
    // neither would send it opening all of them.
    //
    // What stays nil is what the caller wrote rather than what a document
    // does: the entry is an argument to linking and no text holds it, so there
    // is nothing to walk to. Saying `nil` out loud is how that stays
    // distinguishable from a place somebody forgot to carry.
    public init(_ message: String, at place: Place?) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    // MARK: - Private
}

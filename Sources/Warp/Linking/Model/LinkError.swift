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
    // The place is stated and never defaulted. Most of what this refuses is
    // somewhere — and the few that are not are facts about the link rather
    // than about a document: two modules declaring one name is two places, and
    // an entry nobody declares is none. Saying `nil` out loud is how those
    // stay distinguishable from a place somebody forgot to carry.
    public init(_ message: String, at place: Place?) {
        self.message = message
        self.place = place
    }

    // MARK: - Public
    // MARK: - Private
}

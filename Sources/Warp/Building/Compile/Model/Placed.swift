//
//  Placed.swift
//  Warp
//
//  Created by JSilver on 8/30/26.
//

import Foundation

// A declaration gathered from one of several documents: what it holds, and
// where the document wrote it. One value, so a refusal about the declaration
// cannot miss its place.
struct Placed<Held> {
    // MARK: - Property
    let held: Held
    let place: Place

    // Where the caller put the document that wrote it. What tells two
    // documents apart when neither was read from anything, since a module a
    // caller built has no identity.
    let origin: Int

    // What a sentence calls this declaration when it names one among several.
    var spelled: String { place.document.spelled(at: origin) }

    // MARK: - Initializer
    init(_ held: Held, at place: Place, of origin: Int) {
        self.held = held
        self.place = place
        self.origin = origin
    }

    // MARK: - Public
    // MARK: - Private
}

extension Placed: Sendable where Held: Sendable {
}

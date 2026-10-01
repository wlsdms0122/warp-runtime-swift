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

    // Where the host put the document that wrote it. What tells two
    // documents apart when neither was read from anything, since a module a
    // host built has no identity.
    let handed: Int

    // What a sentence calls this declaration when it names one among several.
    var spelled: String { place.document.spelled(at: handed) }

    // MARK: - Initializer
    init(_ held: Held, at place: Place, of handed: Int) {
        self.held = held
        self.place = place
        self.handed = handed
    }

    // MARK: - Public
    // MARK: - Private
}

extension Placed: Sendable where Held: Sendable {
}

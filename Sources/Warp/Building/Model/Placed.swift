//
//  Placed.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// A declaration as the link sees it: what it holds, and where the document
// wrote it.
//
// One value and not two tables held in step by hand. The link renames what it
// gathers (a type declared `Coin` is `wallet.Coin` everywhere after) so where
// the procedures are has to be carried from the pass that renamed them, and a second
// table keyed the same way is a keyspace nothing checks. A refusal that looked
// its place up could miss, and a miss reads as a refusal with no place: the
// error still says what is wrong and stops saying where.
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

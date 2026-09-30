//
//  Scope.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// Where a body is, as far as leaving it is concerned.
//
// One value rather than a parameter each: a body checked without its loops
// reads as a body outside any loop, so carrying the whole is the default and
// every place that breaks it has to say so.
struct Scope: Sendable {
    // MARK: - Property
    // The loops around here, nearest last, a nameless one as nil. A name
    // reaches past the nearer ones, and nothing here means there is no loop
    // to end.
    let rounds: [Name?]

    // The module's bound names, carried so every signature met on the way (a
    // closure's included) refuses a parameter that would take one's place:
    // linking folds a constant wherever its name is read, so a parameter under
    // that name would never be the one that answers.
    let constants: Set<Name>

    // A procedure's own body: no loop yet.
    static let procedure = Scope(rounds: [], constants: [])

    // A procedure written inside another. It may be called anywhere and long
    // after, so the loops around where it was *written* are not around where it
    // runs, and its own answer is its own. What it captured it may write: a
    // variable's box is one thing under one name everywhere the name is
    // visible, and this body is one of those places.
    var enclosed: Scope {
        Scope(rounds: [], constants: constants)
    }

    // MARK: - Initializer
    // MARK: - Public
    static func procedure(constants: Set<Name>) -> Scope {
        Scope(rounds: [], constants: constants)
    }

    func inside(_ round: Name?) -> Scope {
        Scope(rounds: rounds + [round], constants: constants)
    }

    // MARK: - Private
}

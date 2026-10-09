//
//  Scope.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// Where a body is, as far as leaving it and introducing a name are concerned.
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

    // The names the module declares, its constants and its variables,
    // carried so every name introduced on the way (a closure's parameters
    // included) is refused where it would take one's place.
    let bound: Set<Name>

    // The parameters of the procedures this body is written in, a closure's
    // included. No name introduced inside them, at any depth, takes one's
    // spelling.
    let parameters: Set<Name>

    // MARK: - Initializer
    // MARK: - Public
    // A procedure's own body: no loop yet.
    static func procedure(bound: Set<Name>, parameters: Set<Name> = []) -> Scope {
        Scope(rounds: [], bound: bound, parameters: parameters)
    }

    func inside(_ round: Name?) -> Scope {
        Scope(rounds: rounds + [round], bound: bound, parameters: parameters)
    }

    // A procedure written inside another, taking these parameters. It may be
    // called anywhere and long after, so the loops around where it was
    // *written* are not around where it runs, and its own answer is its own.
    // What it captured it may write: a variable's box is one thing under one
    // name everywhere the name is visible, and this body is one of those places.
    func enclosed(taking parameters: Set<Name>) -> Scope {
        Scope(rounds: [], bound: bound, parameters: self.parameters.union(parameters))
    }

    // MARK: - Private
}

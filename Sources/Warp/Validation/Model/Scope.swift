//
//  Scope.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// Where a body is, as far as leaving it and naming a type parameter are
// concerned.
//
// One value rather than a parameter each: a body checked without its loops
// reads as a body outside any loop, so carrying the whole is the default and
// every place that breaks it has to say so.
struct Scope: Sendable {
    // A round of a loop around here: the name the loop binds it under, nil
    // for a nameless loop, and whether the loop may finish, which one written
    // with no condition declares it does not.
    struct Round: Sendable {
        let name: Name?
        let finishes: Bool
    }

    // MARK: - Property
    // The rounds of the loops around here, nearest last. A name reaches past
    // the nearer ones, and nothing here means there is no loop to end.
    let rounds: [Round]

    // The type parameters the procedure this body is written in declares,
    // which are the ones a closure inside it may name.
    let typeParameters: Set<Name>

    // MARK: - Initializer
    // MARK: - Public
    // A procedure's own body: no loop yet.
    static func procedure(typeParameters: Set<Name> = []) -> Scope {
        Scope(rounds: [], typeParameters: typeParameters)
    }

    func inside(_ round: Round) -> Scope {
        Scope(rounds: rounds + [round], typeParameters: typeParameters)
    }

    // A body introduced `name`, and from here the spelling is that name, so a
    // loop around here called by it is called by nothing a leave can write.
    func introducing(_ name: Name) -> Scope {
        let rounds = rounds.map { round in
            Round(name: round.name == name ? nil : round.name, finishes: round.finishes)
        }

        return Scope(rounds: rounds, typeParameters: typeParameters)
    }

    // A procedure written inside another. It may be called anywhere and long
    // after, so the loops around where it was *written* are not around where
    // it runs, and what it returns is its own.
    // What it captured it may write: a variable's box is one thing under one
    // name everywhere the name is visible, and this body is one of those places.
    func enclosed() -> Scope {
        Scope(rounds: [], typeParameters: typeParameters)
    }

    // MARK: - Private
}

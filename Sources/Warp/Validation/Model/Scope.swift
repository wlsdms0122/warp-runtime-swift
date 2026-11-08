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

    // The module variables a closure written here reads and writes when it is
    // called, where what it is written in may not: a constant's and a
    // variable's start. A procedure's body sees them already.
    let moduleVariables: Set<Name>

    // MARK: - Initializer
    // MARK: - Public
    // A procedure's own body: no loop yet.
    static func procedure(typeParameters: Set<Name> = []) -> Scope {
        Scope(rounds: [], typeParameters: typeParameters, moduleVariables: [])
    }

    // A constant or a variable's start: it reads the constants beside it, and
    // a closure literal in it is a procedure of the document, whose body reads
    // and writes the module variables when it is called.
    static func folded(beside moduleVariables: Set<Name>) -> Scope {
        Scope(rounds: [], typeParameters: [], moduleVariables: moduleVariables)
    }

    func inside(_ round: Round) -> Scope {
        Scope(rounds: rounds + [round], typeParameters: typeParameters, moduleVariables: moduleVariables)
    }

    // A body introduced `name`, and from here the spelling is that name, so a
    // loop around here called by it is called by nothing a leave can write.
    func introducing(_ name: Name) -> Scope {
        let rounds = rounds.map { round in
            Round(name: round.name == name ? nil : round.name, finishes: round.finishes)
        }

        return Scope(rounds: rounds, typeParameters: typeParameters, moduleVariables: moduleVariables)
    }

    // A procedure written inside another. It may be called anywhere and long
    // after, so the loops around where it was *written* are not around where
    // it runs, and what it returns is its own.
    // What it captured it may write: a variable's box is one thing under one
    // name everywhere the name is visible, and this body is one of those places.
    // The module variables a constant's or a start's closure reads stand in
    // its body as names it sees, so a closure inside it sees them, or a name
    // its body introduced over one, the way it sees any name.
    func enclosed() -> Scope {
        Scope(rounds: [], typeParameters: typeParameters, moduleVariables: [])
    }

    // MARK: - Private
}

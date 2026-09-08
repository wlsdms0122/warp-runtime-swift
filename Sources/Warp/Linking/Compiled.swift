//
//  Compiled.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What compiling a world answers: every declaration judged and lowered, the
// facts the judgment read off them, and the call graph it gathered on the way.
//
// Everything here is true of the documents alone. Which declaration a run
// starts from is not, so an entry names nothing in this and one world compiled
// once answers every entry asked of it.
struct Compiled: Sendable {
    // MARK: - Property
    // One row per declaration, a document's own taking a run of them
    // in the order the documents stand.
    //
    // The bodies carry their document's own numbers, both for what they call
    // and for what they stand on. The rest of a row does not: what its slots
    // and answer lower to is its signature read against a table, so those are
    // this compile's link reading and are made again wherever the row is
    // read against another.
    let table: [Linked]

    // Every declared spelling, by row.
    let rows: [Name: Int]

    // Every bare spelling a path may step to, by the row it reaches.
    let words: [Name: Int]

    // What each declaration calls, by declared spelling. Read off the bodies
    // as they were judged, so what a link walks is what was proved rather
    // than what a second reading of the same text would find.
    let calls: [Name: [Name]]

    let types: TypeTable

    // Every contract's words, and which declaration answers each by the name
    // of the type that answers it. Which types answer a contract is a fact of
    // the world rather than of one document, so it is what the link reads to
    // fill the calls that go through a contract.
    let contractWords: [Name: ContractWord]

    // Where each document's lowered bodies number their calls from. A body
    // carries the document's own numbers, so this is what the link reads to
    // turn them into rows.
    let numbering: [Int: Numbering]

    // Where each document's lowered bodies number their shapes from. Stands
    // beside the numbering above for the same reason: a body carries the
    // document's own numbers, and which row of a link each one is stays the
    // link's answer.
    let shapeNumbering: [Int: ShapeNumbering]

    // What each document's variables start a run holding, in the order the
    // layouts read them.
    let variables: [Int: [(name: Name, value: Value)]]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

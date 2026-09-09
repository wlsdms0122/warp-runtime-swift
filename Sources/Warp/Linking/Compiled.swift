//
//  Compiled.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What compiling a module graph answers: every declaration judged and lowered, the
// facts the judgment read off them, and the call graph it gathered on the way.
//
// Everything here is true of the documents alone. Which declaration a run
// starts from is not, so an entry names nothing in this and one graph compiled
// once answers every entry asked of it.
struct Compiled: Sendable {
    // MARK: - Property
    // One row per declaration, a document's own taking a run of them
    // in the order the documents stand.
    //
    // The bodies carry their document's own numbers, both for what they call
    // and for what they stand on. The rest of a row does not: what its slots
    // and answer lower to is its signature read against `types`, so a row
    // here stands only against that table. `Relocating` takes it from here
    // rather than from its caller, which is what holds the two together.
    let table: [Linked]

    // Every declared spelling, by row.
    let rows: [Name: Int]

    // Every bare spelling a path may step to, by the row it reaches.
    let words: [Name: Int]

    // Which row each document's closures took, in the order that document
    // numbers them. A closure is a row like any other and no declared spelling
    // reaches it, so it stands here rather than in `rows`.
    let closures: [Int: [Int]]

    // What each declaration calls, by declared spelling. Read off the bodies
    // as they were judged, so what a link walks is what was proved rather
    // than what a second reading of the same text would find.
    let calls: [Name: [Name]]

    let types: TypeTable

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

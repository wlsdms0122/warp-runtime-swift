//
//  Compiled.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What compiling a module graph answers: every document compiled, beside the
// few facts no document could have settled alone.
//
// A document's compile stands on its own and is `Document`. What sits here
// next to them is the graph's. Which declaration a bare spelling reaches
// depends on which types answer which contracts, and that is read off the
// documents together rather than off any one of them.
//
// Which declaration a run starts from is not here either, so an entry names
// nothing in this and one graph compiled once answers every entry asked of it.
struct Compiled: Sendable {
    // One document compiled, in its own coordinates.
    //
    // The rows are this document's alone and numbered from zero: its
    // declarations in name order, then the closures its bodies lifted, in the
    // order the document numbers them. Where the block lands in a link is the
    // link's answer, so nothing here says it.
    struct Document: Sendable {
        // The declared spellings, in the order their rows stand. A row past
        // the end of this is a closure, which no spelling reaches.
        let declared: [Name]

        let table: [Judged]

        // What each declaration calls, beside the spelling it was declared
        // by. Read off the bodies as they were judged, so what a link walks is
        // what was proved rather than what a second reading of the same text
        // would find.
        let calls: [[Name]]

        // Where this document's lowered bodies number their calls and their
        // shapes from. A body carries the document's own numbers, so this is
        // what a link reads to turn them into rows.
        let numbering: Numbering
        let shapeNumbering: ShapeNumbering

        // What this document's variables start a run holding, in the order
        // the layouts read them.
        let variables: [(name: Name, value: Value)]
    }

    // The documents' rows laid end to end, and the tables a link reads them
    // by. Made by `assembled`, which is where a document's rows first stand
    // somewhere.
    struct Assembled: Sendable {
        let table: [Judged]

        // Every declared spelling, by row.
        let rows: [Name: Int]

        // Every bare spelling a path may step to, by the row it reaches, and
        // by the document that steps to it.
        let words: [[Name: Int]]

        // Which row each document's closures took, in the order that document
        // numbers them. A closure is a row like any other and no declared
        // spelling reaches it, so it stands here rather than in `rows`.
        let closures: [[Int]]

        // What each row calls, by row. A closure calls through its own body
        // and is reached by no spelling, so its entry is empty.
        let calls: [[Name]]

        // By document, which is what a body carries and what a row says it
        // came from. Read at every row walked, so read by position.
        let numbering: [Numbering]
        let shapeNumbering: [ShapeNumbering]
        let variables: [[(name: Name, value: Value)]]
    }

    // MARK: - Property
    // By the position the caller handed each module in at, which is what
    // every other number keyed by a document means.
    let documents: [Document]

    // The order the documents stand in, which is the order their blocks are
    // laid down: a document's rows are behind the rows it reaches.
    let standing: [Int]

    // Which declaration a bare spelling a path steps to reaches, by the
    // document that steps to it. A document walks only to what it declared or
    // named, so the reading is that document's.
    //
    // Not the document's own to settle, though: a declaration answering a
    // contract is left out, and which types answer which contracts is a fact
    // of the graph.
    let words: [[Name: Name]]

    let types: TypeTable

    // MARK: - Initializer
    // MARK: - Public
    // Every document's block laid down in the standing order, and the tables
    // that say what a link's rows are. Nothing is judged here and no body is
    // read: the blocks are copied in and the names are answered with where
    // their block began.
    func assembled() -> Assembled {
        let held = documents.reduce(0) { held, document in held + document.table.count }

        var table: [Judged] = []
        var calls: [[Name]] = []
        var rows: [Name: Int] = [:]
        var closures = [[Int]](repeating: [], count: documents.count)

        table.reserveCapacity(held)
        calls.reserveCapacity(held)
        rows.reserveCapacity(held)

        for origin in standing {
            let document = documents[origin]
            let start = table.count

            for (offset, name) in document.declared.enumerated() {
                rows[name] = start + offset
            }

            closures[origin] = (document.declared.count..<document.table.count).map { row in
                start + row
            }

            table.append(contentsOf: document.table)
            calls.append(contentsOf: document.calls)
            calls.append(
                contentsOf: [[Name]](repeating: [], count: document.table.count - document.calls.count)
            )
        }

        return Assembled(
            table: table,
            rows: rows,
            words: words.map { held in held.compactMapValues { declared in rows[declared] } },
            closures: closures,
            calls: calls,
            numbering: documents.map(\.numbering),
            shapeNumbering: documents.map(\.shapeNumbering),
            variables: documents.map(\.variables)
        )
    }

    // MARK: - Private
}

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
// next to them is the graph's: the order the blocks are laid down.
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
    struct Document: Sendable, Declaring {
        // Which document this is, so a refusal a link makes about it says
        // where the words are.
        let document: Place.Document

        // What it declares in the three shape spaces, as it wrote them. A
        // link lays these down in the standing order to make the table its
        // rows are numbered against, and reads no shape of this document
        // anywhere else.
        let types: [Name: TypeExpression]
        let constraints: [Name: [TypeExpression]]
        let contracts: [Name: [Name: Signature]]

        // The declared spellings, in the order their rows stand. A row past
        // the end of this is a closure, which no spelling reaches.
        let declared: [Name]

        let table: [Judged]

        // What each declaration calls, beside the spelling it was declared
        // by. Read off the bodies as they were judged, so what a link walks is
        // what was proved rather than what a second reading of the same text
        // would find.
        let calls: [[Name]]

        // What the link read off a body whose declaration wrote no `returns`,
        // by the spelling it was declared under and in this document's own
        // shape numbers. A declaration that wrote its answer is not here:
        // what an author wrote stands on the row.
        //
        // Read off a body rather than out of a signature, so it is the one
        // thing a document compiled against this cannot work out for itself
        // without reading the body again.
        let answers: [Name: Shape]

        // Which declaration each bare spelling a path in here steps to
        // reaches. A path names only its last segment, and a document steps
        // only to what it declared or named, so the reading is this
        // document's.
        let words: [Name: Name]

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

        // Which document each row's block came from, stamped as the blocks
        // were laid down. A row does not say it, so this is where it is said.
        let origins: [Int]

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

    // MARK: - Initializer
    // MARK: - Public
    // Every document's block laid down in the standing order, and the tables
    // that say what a link's rows are. Nothing is judged here and no body is
    // read: the blocks are copied in and the names are answered with where
    // their block began.
    func assembled() -> Assembled {
        let held = documents.reduce(0) { held, document in held + document.table.count }

        var table: [Judged] = []
        var origins: [Int] = []
        var calls: [[Name]] = []
        var rows: [Name: Int] = [:]
        var closures = [[Int]](repeating: [], count: documents.count)

        table.reserveCapacity(held)
        origins.reserveCapacity(held)
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
            origins.append(contentsOf: [Int](repeating: origin, count: document.table.count))
            calls.append(contentsOf: document.calls)
            calls.append(
                contentsOf: [[Name]](repeating: [], count: document.table.count - document.calls.count)
            )
        }

        return Assembled(
            table: table,
            origins: origins,
            rows: rows,
            words: documents.map { document in
                document.words.compactMapValues { declared in rows[declared] }
            },
            closures: closures,
            calls: calls,
            numbering: documents.map(\.numbering),
            shapeNumbering: documents.map(\.shapeNumbering),
            variables: documents.map(\.variables)
        )
    }

    // MARK: - Private
}

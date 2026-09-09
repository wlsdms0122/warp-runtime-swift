//
//  Assembled.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

// The documents of one link, laid end to end, and the tables that say what
// its rows are. Where a document's rows first stand somewhere.
//
// Nothing is judged here and no body is read: the blocks are copied in, in the
// order the caller handed them over, and the names are answered with where
// their block began.
struct Assembled: Sendable {
    // MARK: - Property
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

    // MARK: - Initializer
    init(_ documents: [Compiled]) {
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

        for (origin, document) in documents.enumerated() {
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

        self.table = table
        self.origins = origins
        self.rows = rows
        self.words = documents.map { document in
            document.words.compactMapValues { declared in rows[declared] }
        }
        self.closures = closures
        self.calls = calls
        self.numbering = documents.map(\.numbering)
        self.shapeNumbering = documents.map(\.shapeNumbering)
        self.variables = documents.map(\.variables)
    }

    // MARK: - Public
    // MARK: - Private
}

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

    // Which document each block came out of, for a refusal that names one.
    let documents: [Place.Document]

    // Which document each row's block came from, stamped as the blocks
    // were laid down. A row does not say it, so this is where it is said.
    let origins: [Int]

    // Every declared spelling, by row.
    let rows: [Name: Int]

    // Which row each document's closures took, in the order that document
    // numbers them. A closure is a row like any other and no declared
    // spelling reaches it, so it stands here rather than in `rows`.
    let closures: [[Int]]

    // By document, which is what a body carries and what a row says it
    // came from. Read at every row walked, so read by position.
    let numbering: [Numbering]
    let typeNumbering: [LoweredTypeNumbering]
    let variables: [[(name: Name, value: Value)]]

    // Which of its writer's closures each row is, by position, for a row a
    // closure was lifted into. Nil for a declaration's own row.
    let written: [Int?]

    // Which documents each writer of a closure stands in. A closure value is
    // spelled by its writer, and the writer's document is whose numbering
    // answers it. Two documents nobody wrote down are told apart by nothing,
    // so a writer of theirs may stand in both, and a closure spelled by it
    // has two answers where it is asked.
    let writing: [Closure.Writer: [Int]]

    // MARK: - Initializer
    init(_ documents: [Compiled]) throws {
        let held = documents.reduce(0) { held, document in held + document.table.count }

        var table: [Judged] = []
        var origins: [Int] = []
        var rows: [Name: Int] = [:]
        var closures = [[Int]](repeating: [], count: documents.count)
        var written: [Int?] = []
        var writing: [Closure.Writer: [Int]] = [:]

        table.reserveCapacity(held)
        origins.reserveCapacity(held)
        rows.reserveCapacity(held)

        for (origin, document) in documents.enumerated() {
            let start = table.count

            for (offset, name) in document.declared.enumerated() {
                // A name two documents declare is a table with no answer for
                // that name, so it is refused where the table is made rather
                // than answered by whichever was laid down last. Documents
                // compiled together are held to this already; documents
                // compiled apart meet here for the first time.
                if let taken = rows[name] {
                    let first = origins[taken]

                    throw BuildError(
                        "'\(name)' is declared by \(documents[first].document.spelled(at: first))"
                            + " and by \(document.document.spelled(at: origin))."
                            + " Two declarations of a name have no way to be told apart",
                        at: .procedure(name.spelling, in: document.document)
                    )
                }

                rows[name] = start + offset
            }

            // A writer's spelling is its document's own, so a closure is
            // spelled by the two together.
            for name in document.numbering.writers {
                writing[Closure.Writer(document: document.document, name: name), default: []].append(origin)
            }

            closures[origin] = document.lifted.map { row in start + row }

            table.append(contentsOf: document.table)
            written.append(contentsOf: document.table.indices.map(document.nth(ofRow:)))
            origins.append(contentsOf: [Int](repeating: origin, count: document.table.count))
        }

        self.table = table
        self.documents = documents.map(\.document)
        self.origins = origins
        self.written = written
        self.writing = writing
        self.rows = rows
        self.closures = closures
        self.numbering = documents.map(\.numbering)
        self.typeNumbering = documents.map(\.typeNumbering)
        self.variables = documents.map(\.variables)
    }

    // MARK: - Public
    // MARK: - Private
}

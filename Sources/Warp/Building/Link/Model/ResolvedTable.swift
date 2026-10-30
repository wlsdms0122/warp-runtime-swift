//
//  ResolvedTable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// A table something may run against, beside how the numbers its bodies carry
// are read.
//
// Running reads rows, and a lowered body carries its document's own numbers,
// so nothing may run against a table until something says which the numbers
// are. `Relocating` says it by writing every body over. Compiling says it
// beside the bodies instead, since it runs a few of them once and writing all
// of them over would cost more than the running.
struct ResolvedTable: Sendable {
    private enum NumberSource: Sendable {
        // This link's own rows.
        case rows

        // Each document's own, by origin, as compiling holds it: where its
        // numbers came from and which row each of them stands for.
        case documents([Lowering.Document])
    }

    // MARK: - Property
    let table: [Linked]
    let rows: [Name: Int]

    // What a closure a run over these rows makes is spelled with, by origin.
    let naming: [Closure.Document]

    private let numbers: NumberSource

    // How a run reads the numbers the bodies carry.
    var resolving: Resolving {
        switch numbers {
        case .rows:
            return .rows

        case let .documents(documents):
            return .documents(documents.map(\.resolved))
        }
    }

    // MARK: - Initializer
    private init(table: [Linked], rows: [Name: Int], naming: [Closure.Document], numbers: NumberSource) {
        self.table = table
        self.rows = rows
        self.naming = naming
        self.numbers = numbers
    }

    // MARK: - Public
    // A table every number of which is a row of it: what `Relocating` made,
    // or rows that carry no lowered body.
    static func relocated(_ table: [Linked], rows: [Name: Int], naming: [Closure.Document]) -> ResolvedTable {
        ResolvedTable(table: table, rows: rows, naming: naming, numbers: .rows)
    }

    // A table as compiling left it, and each document as compiling holds it.
    // The bodies keep the numbers they were lowered with, so what reads one is
    // told which document it came from, and the document says which row each
    // of those numbers stands for.
    static func documents(
        _ table: [Linked],
        rows: [Name: Int],
        naming: [Closure.Document],
        documents: [Lowering.Document]
    ) -> ResolvedTable {
        ResolvedTable(table: table, rows: rows, naming: naming, numbers: .documents(documents))
    }

    // The same resolution over a table lowered since, with the documents as
    // that lowering left them. What a name stands for did not move while the
    // bodies were lowered; the closures are the rows those bodies just made.
    func holding(_ table: [Linked], documents: [Lowering.Document]) -> ResolvedTable {
        switch numbers {
        case .rows:
            return ResolvedTable(table: table, rows: rows, naming: naming, numbers: numbers)

        case .documents:
            return ResolvedTable(table: table, rows: rows, naming: naming, numbers: .documents(documents))
        }
    }

    // MARK: - Private
}

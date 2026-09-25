//
//  Answered.swift
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
struct Answered: Sendable {
    // MARK: - Property
    let table: [Linked]
    let rows: [Name: Int]

    // What a closure a run over these rows makes is spelled with, by origin.
    let naming: [Closure.Document]

    private let numbers: Numbers

    // MARK: - Initializer
    private init(table: [Linked], rows: [Name: Int], naming: [Closure.Document], numbers: Numbers) {
        self.table = table
        self.rows = rows
        self.naming = naming
        self.numbers = numbers
    }

    // A table holding nothing a link could answer: rows built from native
    // procedures alone, which carry no lowered body and send nothing.
    static func unanswerable(_ table: [Linked], rows: [Name: Int], naming: [Closure.Document]) -> Answered {
        Answered(table: table, rows: rows, naming: naming, numbers: .rows)
    }

    // A table as compiling left it, and where each document numbers from. The
    // bodies keep the numbers they were lowered with, so what reads one is
    // told which document it came from, and `named` says which row each of
    // those numbers stands for.
    static func documents(
        _ table: [Linked],
        rows: [Name: Int],
        naming: [Closure.Document],
        numbering: [Int: Numbering],
        named: [Int: [Int?]],
        closures: [Int: [Int]]
    ) -> Answered {
        Answered(
            table: table,
            rows: rows,
            naming: naming,
            numbers: .documents(numbering, named: named, closures: closures)
        )
    }

    // Which row each of one document's numbers stands for, worked out once per
    // number rather than once per body standing on one.
    static func answering(_ numbering: Numbering, rows: [Name: Int], own: [Name: Int]) -> [Int?] {
        numbering.answers(rows: rows, own: own).map { answer -> Int? in
            guard case let .row(row) = answer else { return nil }

            return row
        }
    }

    // A table every number of which `Relocating` made to stand here. The same
    // value as one nothing numbered, since every number is a row now.
    static func relocated(_ table: [Linked], rows: [Name: Int], naming: [Closure.Document]) -> Answered {
        unanswerable(table, rows: rows, naming: naming)
    }

    // MARK: - Public
    // The same answer over a table lowered since, with the closure rows that
    // lowering took. What a name stands for is the documents' and this link's,
    // and neither moved while the bodies were lowered; the closures are the
    // rows those bodies just made, so only they are handed again.
    func holding(_ table: [Linked], closures: [Int: [Int]]) -> Answered {
        switch numbers {
        case .rows:
            return Answered(table: table, rows: rows, naming: naming, numbers: numbers)

        case let .documents(numbering, named, _):
            return Answered(
                table: table,
                rows: rows,
                naming: naming,
                numbers: .documents(numbering, named: named, closures: closures)
            )
        }
    }

    // How a run reads the numbers the bodies carry.
    var resolving: Resolving {
        switch numbers {
        case .rows:
            return .rows

        case let .documents(numbering, named, closures):
            return .documents(
                named.reduce(into: [Int: [Int?]]()) { views, entry in
                    // A closure the link has no row for yet stands as nothing,
                    // the same as a name it has no row for. Constants fold
                    // before any body is lowered, so at that point every one of
                    // them is nothing, and nothing there can reach one.
                    let held = closures[entry.key] ?? []
                    let counted = numbering[entry.key]?.closureCount ?? held.count

                    views[entry.key] = entry.value + (0..<counted).map { written in
                        held.indices.contains(written) ? held[written] : nil
                    }
                }
            )
        }
    }

    // How an expression folded beside a document's bodies is numbered, so that
    // what is lowered now and what was lowered before stand in one numbering.
    // Nothing where the document numbered nothing.
    func numbering(of origin: Int) -> Numbering? {
        switch numbers {
        case .rows:
            return Numbering(rows: rows)

        case let .documents(numbering, _, _):
            return numbering[origin]
        }
    }

    // MARK: - Private
    private enum Numbers: Sendable {
        // This link's own rows.
        case rows

        // Each document's own, with where its numbers came from and which row
        // each of them stands for. The names and the closures stand apart
        // because they settle at different times: a name's row is the link's
        // before anything is lowered, and a closure's row is made by lowering.
        case documents([Int: Numbering], named: [Int: [Int?]], closures: [Int: [Int]])
    }
}

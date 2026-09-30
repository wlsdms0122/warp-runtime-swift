//
//  Carried.swift
//  Warp
//
//  Created by JSilver on 9/11/26.
//

import Foundation

// What documents already compiled leave the one compiled after them.
//
// None of it is read against a table. A row's slots were lowered against one,
// but where a row stands, what number reaches it and what a document proved
// about its own body are the documents' own and move for nothing laid after
// them. What a compile brings of its own is the table, and that is why it is
// not here: everything here is taken as it is.
struct Carried: Sendable {
    // MARK: - Property
    // The rows the documents stand as, and which row each declared spelling
    // reaches.
    let table: [Linked]
    let rows: [Name: Int]

    // The spellings the private declarations wear, which no table of the
    // link's names holds and a refusal reads.
    let concealed: Set<Name>

    // Which row each number a document gave reaches.
    let named: [Int: [Int?]]

    // Each document as it was held, by origin.
    let documents: [Lowering.Document]

    // What the build read off a body whose declaration wrote no `returns`,
    // by row. Everything else the build derived of a declaration stands on
    // its row.
    let answers: [Int: LoweredType]

    // Nothing laid down.
    static let none = Carried(
        table: [],
        rows: [:],
        concealed: [],
        named: [:],
        documents: [],
        answers: [:]
    )

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

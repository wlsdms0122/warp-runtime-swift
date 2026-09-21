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

    // Where each document's block begins, and the spellings its private
    // declarations wear, which no table of names holds.
    let blocks: [Int: Int]
    let owned: [Int: [Name: Int]]
    let hidden: Set<Name>

    // Which row each number a document gave reaches.
    let named: [Int: [Int?]]

    // Where each document's calls are numbered from, which rows its closures
    // took, and its variables in the order a run makes their boxes.
    let numbering: [Int: Numbering]
    let closureRows: [Int: [Int]]
    let variables: [Int: [Name: Int]]

    // What the documents proved about their own bodies, and what the build
    // read off one whose declaration wrote no `returns`.
    let const: Set<Name>
    let isolated: Set<Name>
    let failing: [Name: Failing]
    let answers: [Name: LoweredType]

    // Nothing laid down.
    static let none = Carried(
        table: [],
        rows: [:],
        blocks: [:],
        owned: [:],
        hidden: [],
        named: [:],
        numbering: [:],
        closureRows: [:],
        variables: [:],
        const: [],
        isolated: [],
        failing: [:],
        answers: [:]
    )
}

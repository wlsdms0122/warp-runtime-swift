//
//  Numbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Where a lowered body's numbers come from, and what each one stands for.
//
// A document numbers from itself: the names it looks for outside itself first,
// its own declarations after. A call in its body is one of those numbers and
// nothing else, so what the document lowers to says nothing about the world it
// was linked into, and the same text numbers the same way in every link.
//
// What runs while a link is still being made is numbered by that link's table
// instead. Folding a constant lowers an expression and runs it there and then,
// and code that never leaves has no link afterwards to answer it.
struct Numbering: Sendable {
    // One name a document looks for, and which table answers it. A call names
    // a declaration by its declared spelling; a path names a word by its last
    // step alone, and the two are looked up in different tables. A document's
    // own declaration is looked for the same way an imported one is: the
    // number is the document's, and which row it is stays the link's.
    enum Reference: Sendable {
        case sent(Name)
        case walked(Name)
    }

    // What a number turned out to be, with the reason where it is not a row:
    // a name the link does not have, or a number the document never gave.
    enum Answer: Sendable {
        case row(Int)
        case unfound(Reference)
        case unnumbered
    }

    // MARK: - Property
    private let space: Space
    private let called: [Name: Int]
    private let walked: [Name: Int]

    // MARK: - Initializer
    // A document's own. The imports, the bare spellings its paths step to, and
    // its own declarations, each in name order: the numbering is the
    // document's fact and a set has no order to lend it.
    init(imports: Set<Name>, walks: Set<Name>, declared: [Name]) {
        let sent = imports.sorted()
        let stepped = walks.sorted()

        space = .document(
            sent.map(Reference.sent) + stepped.map(Reference.walked) + declared.map(Reference.sent)
        )
        called = Self.placed(sent, from: 0)
            .merging(Self.placed(declared, from: sent.count + stepped.count)) { _, own in own }
        walked = Self.placed(stepped, from: sent.count)
    }

    // A table's own. The number a body carries here is the row.
    init(rows: [Name: Int], words: [Name: Int]) {
        space = .table
        called = rows
        walked = words
    }

    // MARK: - Public
    // Which row of a link the number stands for, read from the tables that
    // link built.
    func row(_ number: Int, rows: [Name: Int], words: [Name: Int]) -> Answer {
        guard case let .document(references) = space else { return .row(number) }
        guard references.indices.contains(number) else { return .unnumbered }

        let reference = references[number]

        switch reference {
        case let .sent(declared):
            return rows[declared].map(Answer.row) ?? .unfound(reference)

        case let .walked(spelling):
            return words[spelling].map(Answer.row) ?? .unfound(reference)
        }
    }

    // Where a call to this spelling stands: among the document's own
    // declarations where it declared one, among what it looks for otherwise.
    func call(_ selector: Name) -> Int? {
        called[selector]
    }

    // Where a path stepping to this bare spelling stands. Never among a
    // document's own: a bare step is answered from every declaration in the
    // link, so a document declaring that spelling has not thereby answered it.
    func word(_ spelling: Name) -> Int? {
        walked[spelling]
    }

    // MARK: - Private
    // What a number is counted from. The document's list is the whole of the
    // difference: the tables below answer a spelling either way.
    private enum Space: Sendable {
        case document([Reference])
        case table
    }

    private static func placed(_ names: [Name], from start: Int) -> [Name: Int] {
        names.enumerated().reduce(into: [Name: Int]()) { places, entry in
            places[entry.element] = start + entry.offset
        }
    }
}

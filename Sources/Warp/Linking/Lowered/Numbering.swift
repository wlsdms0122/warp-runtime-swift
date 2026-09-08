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
    // What one number stands for, and which table answers it. A call names a
    // declaration by its declared spelling; a path names a word by its last
    // step alone, and the two are looked up in different tables. A document's
    // own declaration is looked for the same way an imported one is: the
    // number is the document's, and which row it is stays the link's.
    enum Reference: Sendable {
        case sent(Name)
        case walked(Name)

        // Already a row, with nothing left to look for.
        case row(Int)
    }

    // MARK: - Property
    private let space: Space

    // MARK: - Initializer
    // A document's own. The imports, the bare spellings its paths step to, and
    // its own declarations, each in name order: the numbering is the
    // document's fact and a set has no order to lend it.
    init(imports: Set<Name>, walks: Set<Name>, declared: [Name]) {
        let sent = imports.sorted()
        let walked = walks.sorted()

        space = .document(
            references: sent.map(Reference.sent)
                + walked.map(Reference.walked)
                + declared.map(Reference.sent),
            call: Self.placed(sent, from: 0)
                .merging(Self.placed(declared, from: sent.count + walked.count)) { _, own in own },
            word: Self.placed(walked, from: sent.count)
        )
    }

    // A table's own. The number a body carries here is the row.
    init(rows: [Name: Int], words: [Name: Int]) {
        space = .table(call: rows, word: words)
    }

    // MARK: - Public
    // What the number stands for, or nil where nothing was numbered there.
    func reference(at number: Int) -> Reference? {
        switch space {
        case let .document(references, _, _):
            return references.indices.contains(number) ? references[number] : nil

        case .table:
            return .row(number)
        }
    }

    // Which row of a link the number stands for, read from the tables that
    // link built. Nil where the link has no such name, which each caller
    // answers for itself.
    func row(_ number: Int, rows: [Name: Int], words: [Name: Int]) -> Int? {
        switch reference(at: number) {
        case let .sent(declared):
            return rows[declared]

        case let .walked(spelling):
            return words[spelling]

        case let .row(row):
            return row

        case nil:
            return nil
        }
    }

    // Where a call to this spelling stands: among the document's own
    // declarations where it declared one, among what it looks for otherwise.
    func call(_ selector: Name) -> Int? {
        switch space {
        case let .document(_, call, _), let .table(call, _):
            return call[selector]
        }
    }

    // Where a path stepping to this bare spelling stands. Never among a
    // document's own: a bare step is answered from every declaration in the
    // link, so a document declaring that spelling has not thereby answered it.
    func word(_ spelling: Name) -> Int? {
        switch space {
        case let .document(_, _, word), let .table(_, word):
            return word[spelling]
        }
    }

    // MARK: - Private
    // The two things a number can be counted from, which are two facts and not
    // one with a flag on it.
    private enum Space: Sendable {
        case document(references: [Reference], call: [Name: Int], word: [Name: Int])
        case table(call: [Name: Int], word: [Name: Int])
    }

    private static func placed(_ names: [Name], from start: Int) -> [Name: Int] {
        names.enumerated().reduce(into: [Name: Int]()) { places, entry in
            places[entry.element] = start + entry.offset
        }
    }
}

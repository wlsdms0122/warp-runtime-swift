//
//  Numbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Where a document's calls are numbered from: the names it looks for outside
// itself stand first, its own declarations after.
//
// A call in a lowered body is one of these numbers and nothing else, so what a
// document lowers to says nothing about the world it was linked into. Which
// row a number means is the link's answer, and the link renumbers.
//
// Built from the document alone, so the same text numbers the same way in
// every link it takes part in.
struct Numbering: Sendable {
    // What one number stands for, and which table answers it. A call names a
    // declaration by its declared spelling; a path names a word by its last
    // step alone, and the two are looked up in different tables. A document's
    // own declaration is looked for the same way an imported one is: the
    // number is the document's, and which row it is stays the link's.
    enum Reference: Sendable {
        case sent(Name)
        case walked(Name)

        // A number that is already a row. What runs while a link is still
        // being made runs in that link's table, so there is nothing to look
        // for.
        case row(Int)
    }

    // MARK: - Property
    // What each number stands for, in the order they are numbered. Nil where
    // the numbering is a table's own, whose numbers are already rows.
    private let references: [Reference]?

    private let sent: [Name: Int]
    private let walked: [Name: Int]
    private let declared: [Name: Int]

    // MARK: - Initializer
    // The document's imports, the bare spellings its paths step to, and its
    // own declarations. Each in name order, since the numbering is the
    // document's fact and a set has no order to lend it.
    init(imports: Set<Name>, walks: Set<Name>, declared: [Name]) {
        let sent = imports.sorted()
        let walked = walks.sorted()

        self.references = sent.map(Reference.sent)
            + walked.map(Reference.walked)
            + declared.map(Reference.sent)
        self.sent = Self.placed(sent, from: 0)
        self.walked = Self.placed(walked, from: sent.count)
        self.declared = Self.placed(declared, from: sent.count + walked.count)
    }

    // A table's own numbering. What runs while a link is still being made
    // runs in that link's table, so the number a call carries there is the
    // row itself and there is nothing to look for later.
    init(rows: [Name: Int], words: [Name: Int]) {
        self.references = nil
        self.sent = [:]
        self.walked = words
        self.declared = rows
    }

    // MARK: - Public
    // What the number stands for, or nil where the document numbered nothing
    // there.
    func reference(at number: Int) -> Reference? {
        guard let references else { return .row(number) }

        return references.indices.contains(number) ? references[number] : nil
    }

    // Where a call to this spelling stands: among the document's own
    // declarations where it declared one, among what it looks for otherwise.
    func call(_ selector: Name) -> Int? {
        declared[selector] ?? sent[selector]
    }

    // Where a path stepping to this bare spelling stands. Never among the
    // document's own: a bare step is answered from every declaration in the
    // link, so a document declaring that spelling has not thereby answered it.
    func word(_ spelling: Name) -> Int? {
        walked[spelling]
    }

    // MARK: - Private
    private static func placed(_ names: [Name], from start: Int) -> [Name: Int] {
        names.enumerated().reduce(into: [Name: Int]()) { places, entry in
            places[entry.element] = start + entry.offset
        }
    }
}

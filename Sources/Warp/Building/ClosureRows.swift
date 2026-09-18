//
//  ClosureRows.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// Which row a closure a value holds stands at, answered from its spelling:
// the writer's document is whose numbering answers, and the number stands
// among the rows that document's closures took. One door for the link and
// for a compile laying objects down, so the two answer alike.
struct ClosureRows {
    // MARK: - Property
    // Which documents each writer of a closure stands in. A document laid
    // twice stands a writer in both places, and a closure spelled by it has
    // two answers where it is asked.
    private let writing: [Closure.Writer: [Int]]

    // Every document of the link, by what a closure of it is spelled with.
    // Read only to say which of two things a refusal is, so a list and not
    // a set: a link hashes nothing for a sentence it does not say.
    private let naming: [Closure.Document]

    private let numbering: [Numbering]
    private let closures: [[Int]]
    private let documents: [Place.Document]

    // MARK: - Initializer
    // The writers are read off the numberings: every name a document
    // numbers closures for writes them, in that document.
    init(
        naming: [Closure.Document],
        numbering: [Numbering],
        closures: [[Int]],
        documents: [Place.Document]
    ) {
        var writing: [Closure.Writer: [Int]] = [:]

        for (origin, numbering) in numbering.enumerated() {
            for name in numbering.writers {
                writing[Closure.Writer(document: naming[origin], name: name), default: []].append(origin)
            }
        }

        self.writing = writing
        self.naming = naming
        self.numbering = numbering
        self.closures = closures
        self.documents = documents
    }

    // MARK: - Public
    func row(of closure: Closure, at place: Place) throws -> Int {
        guard let origins = writing[closure.writer] else {
            throw BuildError(
                naming.contains(closure.writer.document)
                    ? "'\(closure.rendered)', and '\(closure.writer.name)' wrote no closure"
                    : "a closure '\(closure.writer.name)' wrote in a document no module in this link is",
                at: place
            )
        }

        guard origins.count == 1, let origin = origins.first else {
            throw BuildError(
                "a closure '\(closure.writer.name)' wrote, and "
                    + origins.map { origin in documents[origin].spelled(at: origin) }.joined(separator: " and ")
                    + " each write one, with nothing to tell the two apart",
                at: place
            )
        }

        guard let nth = numbering[origin].closure(closure.nth, of: closure.writer.name)?.nth,
              closures[origin].indices.contains(nth)
        else {
            throw BuildError(
                "'\(closure.rendered)', and '\(closure.writer.name)' wrote no such closure",
                at: place
            )
        }

        return closures[origin][nth]
    }
}

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

    private let numbering: [Numbering]
    private let closures: [[Int]]
    private let documents: [Place.Document]

    // MARK: - Initializer
    init(
        writing: [Closure.Writer: [Int]],
        numbering: [Numbering],
        closures: [[Int]],
        documents: [Place.Document]
    ) {
        self.writing = writing
        self.numbering = numbering
        self.closures = closures
        self.documents = documents
    }

    // The same, with the writers read off the numberings: every name a
    // document numbers closures for writes them, in that document.
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

        self.init(writing: writing, numbering: numbering, closures: closures, documents: documents)
    }

    // MARK: - Public
    func row(of closure: Closure, at place: Place) throws -> Int {
        guard let origins = writing[closure.writer], let origin = origins.first else {
            throw BuildError(
                "a closure '\(closure.writer.name)' wrote, and no module in this link writes one",
                at: place
            )
        }

        guard origins.count == 1 else {
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
                "closure \(closure.nth) of '\(closure.writer.name)', which wrote no such closure",
                at: place
            )
        }

        return closures[origin][nth]
    }

    // MARK: - Private
}

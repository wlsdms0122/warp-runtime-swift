//
//  Sending.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Where a native word's declared sends land in the table. A word names the
// spellings it sends and the link answers with rows, so the run reads a row
// where the word wrote a spelling.
//
// A spelling nothing declares is refused here, before anything runs, the same
// way a call written in a document is.
//
// So are the two claims a word makes that sending can contradict. A query is
// the claim that it answers without running, and running is not something a
// caller can catch; an isolated word is the claim that it touches no name
// another body could touch at the same time, and neither is that. A word
// making either claim while sending something that breaks it is refused.
//
// What it may fail with is not one of them. A Swift body can catch, so a word
// declaring it fails nothing while sending something that fails is describing
// itself and not contradicting itself.
struct Sending {
    // MARK: - Property
    private let rows: [Name: Int]

    // Which declarations answer without running, where the link has worked it
    // out. Nil where nothing has: a folding table stands before the purity
    // pass, and a claim it cannot check it does not make.
    private let pure: Set<Name>?

    // Which declarations touch nothing another body could touch at the same
    // time, where the link has worked it out.
    private let isolated: Set<Name>?

    // MARK: - Initializer
    init(rows: [Name: Int], pure: Set<Name>? = nil, isolated: Set<Name>? = nil) {
        self.rows = rows
        self.pure = pure
        self.isolated = isolated
    }

    // MARK: - Public
    func rows(of procedure: Procedure, called label: Name) throws -> [Int] {
        guard let sends = procedure.implementation.nativeImports else { return [] }

        // Only a query claims to answer without running. An effect runs, so
        // what it sends may run too.
        let answersWithoutRunning = procedure.implementation.isNativelyPure == true
        let touchesNothingShared = procedure.implementation.isNativelyIsolated == true

        let ordered = sends.sorted { left, right in left.position < right.position }

        guard ordered.map(\.position) == Array(ordered.indices) else {
            throw LinkError(
                "'\(label)' sends words standing at \(ordered.map(\.position)), which is"
                    + " not one word to a place from the first",
                at: Place.procedure(label.spelling, in: .assembled).part(.imports)
            )
        }

        return try ordered.map { send in
            guard let row = rows[send.selector] else {
                throw LinkError(
                    "'\(label)' sends '\(send.selector)', and nothing in this link declares it",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            guard !answersWithoutRunning || !answersOnlyByRunning(send.selector) else {
                throw LinkError(
                    "'\(label)' answers without running and sends '\(send.selector)',"
                        + " which answers only by running",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            guard !touchesNothingShared || !touchesSomethingShared(send.selector) else {
                throw LinkError(
                    "'\(label)' says it touches no name another body could touch at"
                        + " the same time, and sends '\(send.selector)', which does",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            return row
        }
    }

    // MARK: - Private
    private func answersOnlyByRunning(_ selector: Name) -> Bool {
        guard let pure else { return false }

        return !pure.contains(selector)
    }

    private func touchesSomethingShared(_ selector: Name) -> Bool {
        guard let isolated else { return false }

        return !isolated.contains(selector)
    }
}

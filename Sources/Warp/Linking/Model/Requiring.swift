//
//  Requiring.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The pairs a compile's calls lean on: a type handed where a contract is
// asked, and the place it was handed. The first place a pair is seen at is the
// one kept, so a document handing the same pair in a dozen bodies points at
// one of them.
//
// Held to the document being laid down rather than to the one the reading was
// in. A compile lays one document down at a time and folding runs bodies of
// the ones behind it, so a pair a fold turns up is this document's however
// many bodies the run passed through: the others are compiled already and say
// what they said.
//
// A walk that reads a body rather than judging it writes none of these: the
// ask it walks under carries the ledger, and reading carries no ask that holds
// one. What such a walk concludes is not what the document says.
final class Requiring: @unchecked Sendable {
    // MARK: - Property
    // A `TypeFrame` is `Sendable` and this rides one.
    private let lock = NSLock()
    private var held: [Int: [Claim: Place]] = [:]
    private var origin = 0

    // Where a pair turned up by a fold stands. A call read in text says its
    // own place; a fold has run past the text and has only the document.
    private var folding = Place(in: .assembled)

    // MARK: - Initializer
    init() { }

    // MARK: - Internal
    // The document laid down from here on, and where its refusals stand.
    func laying(_ origin: Int, at place: Place) {
        lock.withLock {
            self.origin = origin
            self.folding = place
        }
    }

    // What is settled inside `body`. A fold runs past the text, so what it
    // turns up says only which declaration was being settled, and that is what
    // this answers.
    //
    // Scoped rather than set, so a walk that leaves early leaves the answer as
    // it found it. Outside every scope the answer is the document, which is
    // what a pair turned up by something other than settling one declaration
    // stands on.
    func folding<Answer>(_ place: Place, _ body: () throws -> Answer) rethrows -> Answer {
        let held = lock.withLock {
            let held = folding
            folding = place

            return held
        }

        defer { lock.withLock { folding = held } }

        return try body()
    }

    func claims(of origin: Int) -> [Claim: Place] {
        lock.withLock { held[origin] ?? [:] }
    }

    func require(_ claim: Claim, at place: Place) {
        lock.withLock { write(claim, at: place) }
    }

    // A pair a fold could not settle, which stands where the document does.
    func require(folded claim: Claim) {
        lock.withLock { write(claim, at: folding) }
    }

    // MARK: - Private
    private func write(_ claim: Claim, at place: Place) {
        guard held[origin, default: [:]][claim] == nil else { return }

        held[origin, default: [:]][claim] = place
    }
}

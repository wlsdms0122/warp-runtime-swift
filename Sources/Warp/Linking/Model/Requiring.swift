//
//  Requiring.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The pairs one document's calls lean on: a type handed where a contract is
// asked, and the place it was handed. The first place a pair is seen at is the
// one kept, so a document handing the same pair in a dozen bodies points at
// one of them.
//
// A walk that reads a body rather than judging it has none of these: the ask
// it walks under carries the ledger, and reading carries no ask that holds
// one. What such a walk concludes is not what the document says.
final class Requiring: @unchecked Sendable {
    // MARK: - Property
    // A `TypeFrame` is `Sendable` and this rides one.
    private let lock = NSLock()
    private var held: [Claim: Place] = [:]

    var claims: [Claim: Place] {
        lock.withLock { held }
    }

    // MARK: - Initializer
    init() {
    }

    // MARK: - Internal
    func require(_ claim: Claim, at place: Place) {
        lock.withLock {
            guard held[claim] == nil else { return }

            held[claim] = place
        }
    }
}

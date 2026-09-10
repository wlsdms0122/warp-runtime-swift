//
//  Requiring.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Where a compile writes down the pairs its calls lean on: a type handed where
// a contract is asked.
//
// Held rather than returned. What is gathered here is seen deep inside the
// reading of a body, and carrying it back up would put a step in every surface
// that reads one. A surface that forgot the step would lose a pair rather than
// refuse, and a lost pair is a call nothing holds to anything.
//
// Written to under the judging ask alone. A reading walk is a probe: a loop
// reads its body until the names settle, and a declaration with no `returns`
// is read once for its answer and thrown away if it cannot be. What such a
// walk concludes is not what the document says, and a pair it left here would
// hold the link to a call the document never makes.
//
// One of these per document compiled, read back when the walk is done.
final class Requiring: @unchecked Sendable {
    // MARK: - Property
    // A frame is `Sendable` and this rides one, so what makes that true is
    // said here rather than assumed of the one walk that writes.
    private let lock = NSLock()
    private var held: [Claim: Place] = [:]

    // What the walk wrote down, and where each pair was leaned on. The first
    // place, so a document with the same pair in a dozen bodies points at one
    // of them rather than at whichever was read last.
    var claims: [Claim: Place] {
        lock.withLock { held }
    }

    // MARK: - Initializer
    init() {
    }

    // MARK: - Internal
    func require(_ claim: Claim, at place: Place, when ask: Linker.Ask) {
        guard case .judging = ask else { return }

        lock.withLock {
            guard held[claim] == nil else { return }

            held[claim] = place
        }
    }
}

//
//  Sending.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Where a native procedure's declared sends stand in its document's numbering. A
// procedure names the spellings it sends and this answers with numbers, so the run
// reads a number where the procedure wrote a spelling.
//
// Which row a number is stays the link's answer, the same as for a call a body
// wrote. A spelling nothing declares is refused there.
//
// Refused here are the two claims a procedure makes that sending can contradict. A
// query is the claim that it answers without running, and running is not
// something a caller can catch; an isolated procedure is the claim that it touches no name
// another body could touch at the same time, and neither is that. A procedure
// making either claim while sending something that breaks it is refused.
//
// What it may fail with is not one of them. A Swift body can catch, so a procedure
// declaring it fails nothing while sending something that fails is describing
// itself and not contradicting itself.
struct Sending {
    // MARK: - Property
    private let numbering: Numbering

    // Which declarations answer without running, where the build has worked it
    // out. Nil where nothing has: a folding table stands before the purity
    // pass, and a claim it cannot check it does not make.
    private let pure: Set<Name>?

    // Which declarations touch nothing another body could touch at the same
    // time, where the build has worked it out.
    private let isolated: Set<Name>?

    // MARK: - Initializer
    init(numbering: Numbering, pure: Set<Name>? = nil, isolated: Set<Name>? = nil) {
        self.numbering = numbering
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
            throw BuildError(
                "'\(label)' sends procedures standing at \(ordered.map(\.position)), which is"
                    + " not one procedure to a place from the first",
                at: Place.procedure(label.spelling, in: .assembled).part(.imports)
            )
        }

        return try ordered.map { send in
            guard let stands = numbering.call(send.selector) else {
                throw BuildError(
                    "'\(label)' sends '\(send.selector)', and its document never asked for it",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            guard !answersWithoutRunning || !answersOnlyByRunning(send.selector) else {
                throw BuildError(
                    "'\(label)' answers without running and sends '\(send.selector)',"
                        + " which answers only by running",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            guard !touchesNothingShared || !touchesSomethingShared(send.selector) else {
                throw BuildError(
                    "'\(label)' says it touches no name another body could touch at"
                        + " the same time, and sends '\(send.selector)', which does",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            return stands
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

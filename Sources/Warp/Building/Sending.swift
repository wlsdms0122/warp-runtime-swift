//
//  Sending.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Where a native procedure's declared sends stand in its document's numbering,
// and where the names each one hands over stand among the parameters it reaches.
// A procedure names the spellings it sends and the arguments it hands at each, and
// this answers with numbers, so the run reads numbers where the procedure wrote
// spellings.
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
    // out. Nil where nothing has: a folding table stands before the constness
    // pass, and a claim it cannot check it does not make.
    private let const: (@Sendable (Name) -> Bool)?

    // Which declarations touch nothing another body could touch at the same
    // time, where the build has worked it out.
    private let isolated: (@Sendable (Name) -> Bool)?

    // What a selector this document may send takes, where the build has the
    // declaration in hand. Nil for a spelling nothing standing so far declares,
    // which is only reachable for a send that hands nothing over.
    private let taking: @Sendable (Name) -> Signature?

    // MARK: - Initializer
    init(
        numbering: Numbering,
        const: (@Sendable (Name) -> Bool)? = nil,
        isolated: (@Sendable (Name) -> Bool)? = nil,
        taking: @escaping @Sendable (Name) -> Signature?
    ) {
        self.numbering = numbering
        self.const = const
        self.isolated = isolated
        self.taking = taking
    }

    // MARK: - Public
    func rows(of procedure: Procedure, called label: Name) throws -> [Sent] {
        guard let sends = procedure.implementation.nativeImports else { return [] }

        // Only a query claims to answer without running. An effect runs, so
        // what it sends may run too.
        let answersWithoutRunning = procedure.implementation.isNativelyConst == true
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

            // A spelling no declaration standing here answers for is the
            // link's to refuse, as undeclared or as another document's
            // private; what it does is judged only with the declaration in
            // hand.
            let declared = taking(send.selector) != nil

            guard !declared || !answersWithoutRunning || !answersOnlyByRunning(send.selector) else {
                throw BuildError(
                    "'\(label)' answers without running and sends '\(send.selector)',"
                        + " which answers only by running",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            guard !declared || !touchesNothingShared || !touchesSomethingShared(send.selector) else {
                throw BuildError(
                    "'\(label)' says it touches no name another body could touch at"
                        + " the same time, and sends '\(send.selector)', which does",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            return Sent(row: stands, handing: try positions(of: send, called: label))
        }
    }

    // MARK: - Private
    // Where each name a send hands over stands among the parameters it reaches.
    // The order is the callee's declaration order, which is the order its
    // slots stand in and the order a run reads them at, so this is the same
    // answer a call written in a body gets from the build.
    private func positions(of send: Native.Send, called label: Name) throws -> [Int] {
        guard !send.handing.isEmpty else { return [] }

        guard let signature = taking(send.selector) else {
            throw BuildError(
                "'\(label)' hands \(send.handing.map(\.spelling).joined(separator: ", ")) to"
                    + " '\(send.selector)', and nothing standing here declares what it takes",
                at: Place.procedure(label.spelling, in: .assembled).part(.imports)
            )
        }

        let names = signature.names
        var taken: Set<Int> = []

        // A name handed twice is two instructions for one place, and neither is
        // the one to keep. The same rule a call written in a body is held to.
        return try send.handing.map { handed in
            guard let position = names.firstIndex(of: handed) else {
                throw BuildError(
                    "'\(label)' hands '\(handed)' to '\(send.selector)', which declares"
                        + " no parameter under that name",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            guard taken.insert(position).inserted else {
                throw BuildError(
                    "'\(label)' hands '\(handed)' to '\(send.selector)' more than once",
                    at: Place.procedure(label.spelling, in: .assembled).part(.imports)
                )
            }

            return position
        }
    }

    private func answersOnlyByRunning(_ selector: Name) -> Bool {
        guard let const else { return false }

        return !const(selector)
    }

    private func touchesSomethingShared(_ selector: Name) -> Bool {
        guard let isolated else { return false }

        return !isolated(selector)
    }
}

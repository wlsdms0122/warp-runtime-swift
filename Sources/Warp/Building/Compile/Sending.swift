//
//  Sending.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Where a native procedure's declared sends stand in its document's numbering,
// and how many arguments each one hands over. A procedure names the spellings it
// sends and how many it hands at each, and this answers with numbers, so the run
// reads numbers where the procedure wrote spellings.
//
// Which row a number is stays the link's answer, the same as for a call a body
// wrote. A spelling nothing standing declares is refused here, the way a call
// a body wrote is.
//
// Refused here are the two claims a procedure makes that sending can contradict. A
// query is the claim that it answers without running, and running is not
// something a caller can catch; an isolated procedure is the claim that it touches no name
// another body could touch at the same time, and neither is that. A procedure
// making either claim while sending something that breaks it is refused. So is
// a send reaching a parameter handed in place, since a send hands values.
//
// What it may fail with is not one of them. A Swift body can catch, so a procedure
// declaring it fails nothing while sending something that fails is describing
// itself and not contradicting itself.
struct Sending {
    // MARK: - Property
    private let numbering: Numbering

    // Which declarations answer without running.
    private let const: @Sendable (Name) -> Bool

    // Which declarations touch nothing another body could touch at the same
    // time.
    private let isolated: @Sendable (Name) -> Bool

    // What a selector this document may send takes. Nil for a spelling
    // nothing standing declares.
    private let taking: @Sendable (Name) -> Signature?

    // The spellings only another document's private declarations wear.
    private let concealed: Set<Name>

    // MARK: - Initializer
    init(
        numbering: Numbering,
        const: @escaping @Sendable (Name) -> Bool,
        isolated: @escaping @Sendable (Name) -> Bool,
        taking: @escaping @Sendable (Name) -> Signature?,
        concealing concealed: Set<Name>
    ) {
        self.numbering = numbering
        self.const = const
        self.isolated = isolated
        self.taking = taking
        self.concealed = concealed
    }

    // MARK: - Public
    func rows(of symbol: Symbol) throws -> [Sent] {
        let implementation = symbol.procedure.implementation
        let label = symbol.declared
        let place = symbol.place.part(.imports)

        guard let sends = implementation.nativeImports else { return [] }

        // Only a query claims to answer without running. An effect runs, so
        // what it sends may run too.
        let answersWithoutRunning = implementation.isNativelyConst == true
        let touchesNothingShared = implementation.isNativelyIsolated == true

        return try numbering.sent(sends, by: label) { send in
            guard let signature = taking(send.selector) else {
                guard !concealed.contains(send.selector) else {
                    throw BuildError.concealed(send.selector, at: place)
                }

                throw BuildError("sends '\(send.selector)', which no module in this link declares", at: place)
            }

            guard !answersWithoutRunning || const(send.selector) else {
                throw BuildError(
                    "'\(label)' answers without running and sends '\(send.selector)',"
                        + " which answers only by running",
                    at: place
                )
            }

            guard !touchesNothingShared || isolated(send.selector) else {
                throw BuildError(
                    "'\(label)' says it touches no name another body could touch at"
                        + " the same time, and sends '\(send.selector)', which does",
                    at: place
                )
            }

            return try handing(of: send, reaching: signature, called: label, at: place)
        }
    }

    // MARK: - Private
    // How many arguments a send hands over, held against the parameters it
    // reaches by the same rule a call written in a body is held to.
    private func handing(
        of send: Native.Send,
        reaching signature: Signature,
        called label: Name,
        at place: Place
    ) throws -> Int {
        guard send.handing == signature.parameters.count else {
            throw BuildError(
                "'\(label)' sends '\(send.selector)' \(send.handing) arguments, and it takes"
                    + " \(signature.parameters.count)",
                at: place
            )
        }

        // A send hands values, and a parameter handed in place takes a
        // variable.
        if let parameter = signature.inPlace {
            throw BuildError(
                "'\(label)' sends '\(send.selector)', which takes '\(parameter)' in place,"
                    + " and a send hands values",
                at: place
            )
        }

        return send.handing
    }
}

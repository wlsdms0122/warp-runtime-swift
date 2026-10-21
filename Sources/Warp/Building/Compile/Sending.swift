//
//  Sending.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Where a native procedure's declared sends stand in its document's numbering.
// A procedure names the spellings it sends and how many it hands at each, and
// this answers with numbers, so the run reads numbers where the procedure
// wrote spellings, and holds each count to the parameters the send reaches.
//
// Which row a number is stays the link's answer, the same as for a call a body
// wrote. A spelling nothing standing declares is refused here, the way a call
// a body wrote is. So is a contract's procedure: a send names the declaration
// it reaches, and which declaration answers a contract's procedure is a
// call's first argument to say.
//
// Refused here are the claims a declaration makes that its native code can
// contradict. A const declaration is the claim that it answers without
// running, and running is not something a caller can catch; an isolated one
// is the claim that it touches no name another body could touch at the same
// time, and neither is that. An effect claiming const is refused, since it
// runs, and so is a declaration making either claim while sending something
// that breaks it. So is a send reaching a parameter handed in place, since a
// send hands values.
struct Sending {
    // MARK: - Property
    private let numbering: Numbering

    // What a declaration this document may send takes. Nil for a spelling
    // no declaration standing wears.
    private let taking: @Sendable (Name) -> Signature?

    // The spellings of the contracts' procedures, which no declaration wears.
    private let contractProcedures: Set<Name>

    // The spellings only another document's private declarations wear.
    private let concealed: Set<Name>

    // MARK: - Initializer
    init(
        numbering: Numbering,
        taking: @escaping @Sendable (Name) -> Signature?,
        contractProcedures: Set<Name>,
        concealing concealed: Set<Name>
    ) {
        self.numbering = numbering
        self.taking = taking
        self.contractProcedures = contractProcedures
        self.concealed = concealed
    }

    // MARK: - Public
    func rows(of symbol: Symbol) throws -> [Sent] {
        let implementation = symbol.procedure.implementation
        let label = symbol.declared
        let place = symbol.place.part(.imports)

        guard let sends = implementation.nativeImports else { return [] }

        let declared = symbol.procedure.signature

        if declared.constness == .const, case .effect = implementation {
            throw BuildError(
                "'\(label)' is declared const and answered by an effect, which answers by running",
                at: symbol.place
            )
        }

        do {
            return try numbering.sent(sends) { send in
                guard let signature = taking(send.selector) else {
                    guard !contractProcedures.contains(send.selector) else {
                        throw BuildError(
                            "sends '\(send.selector)', which is a contract's procedure. A send names"
                                + " the declaration it reaches, and which declaration answers a"
                                + " contract's procedure is a call's first argument to say",
                            at: place
                        )
                    }

                    guard !concealed.contains(send.selector) else {
                        throw BuildError.concealed(send.selector, at: place)
                    }

                    throw BuildError("sends '\(send.selector)', which no module in this link declares", at: place)
                }

                // A failure out of what it sends comes back to the native
                // code, which may catch it, so only what it declares of its
                // own failures says what comes out of it.
                switch signature.effects.exceeding(declared.effects) {
                case .constness:
                    throw BuildError(
                        "'\(label)' answers without running and sends '\(send.selector)',"
                            + " which answers only by running",
                        at: place
                    )

                case .isolation:
                    throw BuildError(
                        "'\(label)' says it touches no name another body could touch at"
                            + " the same time, and sends '\(send.selector)', which does",
                        at: place
                    )

                case .failing, nil:
                    break
                }

                try handing(of: send, reaching: signature, called: label, at: place)
            }
        } catch let .unnumbered(selector) as SendNumberingError {
            throw BuildError("'\(label)' sends '\(selector)', and its document never asked for it", at: place)
        }
    }

    // MARK: - Private
    // How many arguments a send hands over, held against the parameters it
    // reaches: one value to each.
    private func handing(
        of send: Native.Send,
        reaching signature: Signature,
        called label: Name,
        at place: Place
    ) throws {
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
    }
}

//
//  LoweredContractProcedure.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// One procedure of one contract, under the spelling a call writes to reach it:
// the contract's own name and the procedure's, with a dot between them.
//
// A call that writes it names no declaration. What answers it is decided by
// the value it is sent to, which is why it is gathered apart from the symbols:
// everything in that table is one declaration, and this is a table of them.
struct LoweredContractProcedure: Sendable {
    // MARK: - Property
    let contract: Name
    let procedure: Name

    // What the contract said the procedure takes and answers, `Self` read as
    // the type parameter a call fills. It takes `Self` first: whatever
    // satisfies the contract stands there, which is the whole reason the
    // procedure is in one.
    let signature: Signature

    // What the contract asks of every declaration answering it beyond the
    // signature, which is what a call through the contract reads as.
    let constness: Constness
    let isolation: Isolation

    // The same declaration as the run reads it, lowered once here. A procedure
    // in a contract declares no row, so this is the only place its lowering
    // could live.
    let slots: [Slot]
    let answers: LoweredType?

    // Which declaration answers this procedure, by the name of the type that
    // answers it. The link filled this in for every type it found, so a call
    // reads a row out of it rather than resolving anything.
    let answering: [Name: Name]

    // MARK: - Initializer
    // MARK: - Public
    // Every procedure every contract in these tables asks, under the spelling
    // a call writes to reach one.
    //
    // Which declaration answers one is read off the tables rather than carried
    // from where the answers were gathered. A type answering a contract
    // answers every one of its procedures by a declaration named for the type
    // and the procedure, so the table saying which types answer says the whole
    // of it.
    static func table(in types: TypeTable) -> [Name: LoweredContractProcedure] {
        types.contracts.reduce(into: [Name: LoweredContractProcedure]()) { table, entry in
            let answering = types.loweredTypes.satisfying[entry.key] ?? []

            for (procedure, asked) in entry.value {
                let signature = asked.signature.read(of: entry.key)

                table[ContractProcedure.spelling(of: entry.key, procedure: procedure)] = LoweredContractProcedure(
                    contract: entry.key,
                    procedure: procedure,
                    signature: signature,
                    constness: asked.constness,
                    isolation: asked.isolation,
                    slots: signature.lowered(in: types.loweredTypes),
                    answers: signature.returns?.lowered(in: types.loweredTypes),
                    answering: answering.reduce(into: [Name: Name]()) { held, type in
                        held[type] = ContractProcedure.spelling(of: type, procedure: procedure)
                    }
                )
            }
        }
    }

    // MARK: - Private
}

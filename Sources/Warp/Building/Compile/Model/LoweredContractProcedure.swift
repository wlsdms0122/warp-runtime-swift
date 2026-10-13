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
    let failing: Set<String>

    // The same declaration as the run reads it, lowered once here. A procedure
    // in a contract declares no row, so this is the only place its lowering
    // could live.
    let slots: [Slot]
    let answers: LoweredType?

    // MARK: - Initializer
    // MARK: - Public
    // Which declaration answers this procedure, by the name of the type that
    // answers it, among the claims `table` holds: a type answering a contract
    // answers every one of its procedures by its member of that name.
    func answering(in table: LoweredTypeTable) -> [Name: Name] {
        (table.satisfying[contract]?.keys).map { types in
            types.reduce(into: [Name: Name]()) { held, type in held[type] = procedure.spelled(under: type) }
        } ?? [:]
    }

    // Every procedure every contract in these tables asks, under the spelling
    // a call writes to reach one.
    //
    // What a contract asks is its declaration's, so this is the same whichever
    // claims a table holds, and which declaration answers is asked of a table
    // where a call is answered.
    static func table(in types: TypeTable) -> [Name: LoweredContractProcedure] {
        types.contracts.reduce(into: [Name: LoweredContractProcedure]()) { table, entry in
            for (procedure, asked) in entry.value.procedures {
                let signature = asked.signature.read(of: entry.key)

                table[procedure.spelled(under: entry.key)] = LoweredContractProcedure(
                    contract: entry.key,
                    procedure: procedure,
                    signature: signature,
                    constness: asked.constness,
                    isolation: asked.isolation,
                    failing: asked.failing,
                    slots: signature.lowered(in: types.loweredTypes),
                    answers: signature.loweredReturns(in: types.loweredTypes)
                )
            }
        }
    }

    // MARK: - Private
}

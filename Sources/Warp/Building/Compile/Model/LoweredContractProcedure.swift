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
// A call that writes it names no declaration. Which declaration satisfies it
// is decided by the type that fills `Self` at it, which is why it is gathered apart
// from the symbols: everything in that table is one declaration, and this is
// a table of them.
struct LoweredContractProcedure: Sendable {
    // MARK: - Property
    let contract: Name
    let procedure: Name

    // What the contract asks of every declaration satisfying it, `Self` read
    // as the type parameter a call fills, which is what a call through the
    // contract reads as. It takes `Self` first: whatever satisfies the
    // contract stands there, which is the whole reason the procedure is in
    // one.
    let signature: Signature

    // The same declaration as the run reads it, lowered once here. A procedure
    // in a contract declares no row, so this is the only place its lowering
    // could live.
    let slots: [Slot]
    let returns: LoweredType

    // MARK: - Initializer
    // MARK: - Public
    // Which declaration satisfies this procedure, by the name of the type that
    // conforms to its contract, among the claims `table` holds: a type
    // conforming to a contract satisfies every one of its procedures by its
    // member of that name.
    func witnesses(in table: LoweredTypeTable) -> [Name: Name] {
        (table.satisfying[contract]?.keys).map { types in
            types.reduce(into: [Name: Name]()) { held, type in held[type] = procedure.spelled(under: type) }
        } ?? [:]
    }

    // Every procedure every contract in these tables asks, under the spelling
    // a call writes to reach one.
    //
    // What a contract asks is its declaration's, so this is the same whichever
    // claims a table holds, and which declaration satisfies one is asked of a
    // table where a call is resolved.
    static func table(in types: TypeTable) -> [Name: LoweredContractProcedure] {
        types.contracts.reduce(into: [Name: LoweredContractProcedure]()) { table, entry in
            for (procedure, asked) in entry.value.procedures {
                let signature = asked.read(of: entry.key)

                table[procedure.spelled(under: entry.key)] = LoweredContractProcedure(
                    contract: entry.key,
                    procedure: procedure,
                    signature: signature,
                    slots: signature.lowered(in: types.loweredTypes),
                    returns: signature.loweredReturns(in: types.loweredTypes)
                )
            }
        }
    }

    // MARK: - Private
}

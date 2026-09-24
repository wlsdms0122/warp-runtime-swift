//
//  Parameter+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

extension Parameter {
    // This parameter as the run reads it. An undeclared type lowers to
    // `any`: the boundary tells "nothing written" from "`any` written" in no
    // way, so the slot does not either.
    func lowered(in table: LoweredTypeTable) -> Slot {
        slot(holding: declared.lowered(in: table), in: table)
    }

    // The same, with what a call put in the type parameters written in. A
    // parameter nothing filled reads `any`, which is what the call said about
    // it by saying nothing.
    func lowered(in table: LoweredTypeTable, filling bound: [Name: LoweredType]) -> Slot {
        slot(holding: declared.lowered(in: table).filling(bound), in: table)
    }

    private func slot(holding type: LoweredType, in table: LoweredTypeTable) -> Slot {
        Slot(
            name: name,
            type: type,
            candidates: candidates.map { written in
                written.map { spelling in Candidate(spelling, in: type, reading: table) }
            }
        )
    }
}

//
//  Parameter+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

extension Parameter {
    // This parameter as the run reads it. An undeclared type lowers to
    // `Any`: the boundary tells "nothing written" from "`Any` written" in no
    // way, so the slot does not either. `bounds` are what the signature
    // holds its type parameters to.
    func lowered(in table: LoweredTypeTable, bounds: [Name: Set<Name>]) -> Slot {
        Slot(name: name, type: declared.lowered(in: table, bounds: bounds))
    }

    // The same, with what a call put in the type parameters written in. A
    // parameter nothing filled reads `Any`, which is what the call said about
    // it by saying nothing.
    func lowered(
        in table: LoweredTypeTable,
        bounds: [Name: Set<Name>],
        filling bound: [Name: LoweredType]
    ) -> Slot {
        Slot(name: name, type: declared.lowered(in: table, bounds: bounds).filling(bound))
    }
}

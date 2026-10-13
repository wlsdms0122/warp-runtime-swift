//
//  Parameter+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

extension Parameter {
    // This parameter as the run reads it. `bounds` and `sameTypes` are what
    // the signature holds its type parameters and their members to.
    func lowered(in table: LoweredTypeTable, bounds: [Name: Set<Name>], sameTypes: [Name: TypeExpression] = [:]) -> Slot {
        Slot(name: name, type: type.lowered(in: table, bounds: bounds, sameTypes: sameTypes))
    }
}

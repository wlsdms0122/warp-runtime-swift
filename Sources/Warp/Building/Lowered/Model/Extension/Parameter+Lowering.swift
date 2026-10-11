//
//  Parameter+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

extension Parameter {
    // This parameter as the run reads it. `bounds` are what the signature
    // holds its type parameters to.
    func lowered(in table: LoweredTypeTable, bounds: [Name: Set<Name>]) -> Slot {
        Slot(name: name, type: type.lowered(in: table, bounds: bounds))
    }
}

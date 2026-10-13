//
//  Signature+Environment.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

extension Signature {
    // The environment a procedure's body starts from: its own parameters,
    // which are the only names declared before the first statement.
    func environment(in table: LoweredTypeTable) -> [Name: Binding] {
        Dictionary(
            parameters.map { parameter in
                (parameter.name, Binding(parameter: parameter.lowered(in: table, bounds: bounds, sameTypes: sameTypes).type))
            }
        ) { first, _ in first }
    }
}

//
//  ContractProcedure+Operation.swift
//  WarpStandard
//
//  Created by JSilver on 10/7/26.
//

import Foundation
import Warp

extension ContractProcedure {
    // A procedure of two of the type answering the contract, `lhs` and `rhs`,
    // answering without running and touching nothing, as a host's own
    // arithmetic and ordering do.
    static func operation(answering returns: TypeExpression) -> ContractProcedure {
        ContractProcedure(
            signature: Signature(
                parameters: [Parameter(name: "lhs", type: .selfType), Parameter(name: "rhs", type: .selfType)],
                returns: returns
            ),
            constness: .const,
            isolation: .isolated
        )
    }
}

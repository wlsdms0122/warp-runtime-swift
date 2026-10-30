//
//  Signature+Operation.swift
//  WarpStandard
//
//  Created by JSilver on 10/7/26.
//

import Foundation
import Warp

extension Signature {
    // A procedure of two of the type conforming to the contract, `lhs` and
    // `rhs`, const and touching nothing, as a host's own
    // arithmetic and ordering do.
    static func operation(returning returns: TypeExpression) -> Signature {
        Signature(
            parameters: [Parameter(name: "lhs", type: .selfType), Parameter(name: "rhs", type: .selfType)],
            returns: returns,
            constness: .const,
            isolation: .isolated
        )
    }
}

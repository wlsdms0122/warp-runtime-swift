//
//  Procedure+Witness.swift
//  WarpStandard
//
//  Created by JSilver on 10/7/26.
//

import Foundation
import Warp

extension Procedure {
    // A native procedure satisfying a contract's procedure for one type: every
    // parameter the query reads, in its order, taking that type, each type
    // parameter it writes held to `bounds`, const and touching nothing, the way
    // the contracts here ask.
    static func witness<Q: Query>(
        _ query: Q,
        taking type: TypeExpression,
        returns: TypeExpression,
        bounds: [Name: Set<Name>] = [:]
    ) -> Procedure {
        Procedure(
            signature: Signature(
                parameters: Q.Parameters.allCases.map { parameter in Parameter(name: parameter.name, type: type) },
                returns: returns,
                constness: .const,
                isolation: .isolated,
                bounds: bounds
            ),
            implementation: .query(query)
        )
    }
}

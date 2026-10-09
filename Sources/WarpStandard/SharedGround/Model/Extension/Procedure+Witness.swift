//
//  Procedure+Witness.swift
//  WarpStandard
//
//  Created by JSilver on 10/7/26.
//

import Foundation
import Warp

extension Procedure {
    // A host procedure answering a contract's procedure for one type: every
    // parameter the query reads, in its order, taking that type.
    static func witness<Q: Query>(
        _ query: Q,
        taking type: TypeExpression,
        returns: TypeExpression,
        description: String
    ) -> Procedure {
        Procedure(
            description: description,
            signature: Signature(
                parameters: Q.Parameters.allCases.map { parameter in Parameter(name: parameter.name, type: type) },
                returns: returns
            ),
            implementation: .query(query)
        )
    }
}

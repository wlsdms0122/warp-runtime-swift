//
//  Module+Signatures.swift
//  WarpTestSupport
//
//  Created by JSilver on 9/21/26.
//

import Foundation
import Warp

public extension Module {
    // A module whose contracts are written as signatures alone, asking
    // nothing beyond them. What most tests declare, kept to one line each.
    init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeExpression] = [:],
        contracts: [Name: [Name: Signature]],
        claims: [Name: Set<Name>] = [:],
        constants: [Name: Warp.Expression] = [:],
        variables: [Name: Warp.Expression] = [:],
        procedures: [Name: Procedure],
        identity: Identity? = nil,
        builtin: Bool = false
    ) throws {
        try self.init(
            description: description,
            imports: imports,
            types: types,
            contracts: contracts.mapValues { procedures in procedures.mapValues { signature in ContractProcedure(signature: signature) } },
            claims: claims,
            constants: constants,
            variables: variables,
            procedures: procedures,
            identity: identity,
            builtin: builtin
        )
    }
}

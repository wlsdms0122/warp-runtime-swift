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
        imports: Set<Name>? = nil,
        types: [Name: TypeDeclaration] = [:],
        contracts: [Name: [Name: Signature]],
        claims: [Head: Set<Name>] = [:],
        members: [Head: Set<Name>] = [:],
        constants: [Name: Warp.Expression] = [:],
        variables: [Name: Warp.Expression] = [:],
        procedures: [Name: Procedure] = [:],
        builtin: Bool = false
    ) throws {
        try self.init(
            imports: imports,
            types: types,
            contracts: contracts.mapValues { procedures in
                Contract(procedures: procedures)
            },
            claims: claims,
            members: members,
            constants: constants,
            variables: variables,
            procedures: procedures,
            builtin: builtin
        )
    }
}

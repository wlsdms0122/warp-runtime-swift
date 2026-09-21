//
//  Module+Publishing.swift
//  WarpTestSupport
//

import Foundation
import Warp

public extension Module {
    // This module with the entry made public, where it declares one. A test
    // names the entry outside the text, so the text is not where the word is
    // written.
    func publishing(_ entry: Name) throws -> Module {
        guard let procedure = procedures[entry] else { return self }

        return try Module(
            draft.declaring(procedures.merging([entry: procedure.with(access: .public)]) { _, new in new }),
            identity: identity,
            builtin: builtin
        )
    }
}

public extension Module {
    // A module whose contracts are written as signatures alone, asking
    // nothing beyond them. What most tests declare, kept to one line each.
    init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
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
            constraints: constraints,
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

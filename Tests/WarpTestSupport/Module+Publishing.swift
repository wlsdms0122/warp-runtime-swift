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

        let draft = self.draft

        return try Module(
            Draft(
                description: draft.description,
                imports: draft.imports,
                types: draft.types,
                constraints: draft.constraints,
                contracts: draft.contracts,
                claims: draft.claims,
                constants: draft.constants,
                variables: draft.variables,
                procedures: draft.procedures.merging([entry: procedure.with(access: .public)]) { _, new in new }
            ),
            identity: identity,
            builtin: builtin
        )
    }
}

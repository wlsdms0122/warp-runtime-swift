//
//  Module+Publishing.swift
//  WarpTestSupport
//
//  Created by JSilver on 9/30/26.
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

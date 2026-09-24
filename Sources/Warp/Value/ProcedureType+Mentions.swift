//
//  ProcedureType+Mentions.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

extension ProcedureType {
    // Every declared name this type reaches, through what it takes and what
    // it answers.
    var mentions: Set<Name> {
        parameters.reduce(into: returns?.mentions ?? []) { mentioned, parameter in
            mentioned.formUnion(parameter.mentions)
        }
    }
}

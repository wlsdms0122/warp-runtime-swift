//
//  ProcedureType+Parameters.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// The type parameters a procedure type mentions. Its parameters are the
// declaring signature's own slots, so they are collected and bounded the way
// the signature's are.
public extension ProcedureType {
    var isGeneric: Bool {
        parameters.contains { parameter in parameter.isGeneric }
            || (returns?.isGeneric ?? false)
    }

    // Every type parameter mentioned in this type, occurrence by occurrence.
    var parameterOccurrences: [ParameterOccurrence] {
        parameters.flatMap { parameter in parameter.parameterOccurrences }
            + (returns?.parameterOccurrences ?? [])
    }

    // What this type holds its type parameters to, read off every occurrence.
    var parameterBounds: ParameterBounds {
        ParameterBounds(parameterOccurrences)
    }

    // This type with each occurrence carrying the bound declared for its
    // name. The one `bounds` at the declaration speaks for a nested type.
    func bounded(by bounds: [Name: [Name]]) -> ProcedureType {
        ProcedureType(
            parameters: parameters.map { parameter in parameter.bounded(by: bounds) },
            returns: returns?.bounded(by: bounds)
        )
    }
}

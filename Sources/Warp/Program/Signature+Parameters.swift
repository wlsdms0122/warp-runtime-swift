//
//  Signature+Parameters.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// The type parameters a declaration writes: which names it mentions, what
// each is bounded by, and whether it has any at all. What a call puts in them
// is read off the lowered declaration, where the readings are.
public extension Signature {
    var isGeneric: Bool {
        parameters.contains { parameter in parameter.declared.isGeneric }
            || (returns?.isGeneric ?? false)
    }

    // Every type parameter mentioned in this signature, occurrence by
    // occurrence. A nested procedure type's parameters are collected too:
    // they are this signature's own slots, `map` takes `array<some Element>`
    // beside a procedure taking the same `some Element`, and it is one
    // parameter filled by one call. Only a parameter behind a `named`
    // type is not collected, because the link refuses one anywhere but a
    // procedure signature and never fills one through the name.
    var parameterOccurrences: [ParameterOccurrence] {
        parameters.flatMap { parameter in parameter.declared.parameterOccurrences }
            + (returns?.parameterOccurrences ?? [])
    }

    // The bounds each type parameter this signature declares is held to: the
    // set a bounded mention carries, or none where every mention is bare.
    // What a signature holds a name to is one set, so two mentions carrying
    // two sets are two claims about one name, and this says which name.
    var parameterBounds: ParameterBounds {
        ParameterBounds(parameterOccurrences)
    }

    // This signature with each type parameter's occurrences carrying the
    // constraint declared for its name. The signature owns the bound and the
    // occurrences read it. A notation writes `bounds: { N: Numeric }` once and
    // `some N` in the slots, and this is where the one meets the many.
    //
    // An occurrence already carrying a bound keeps it: a nested procedure
    // type may have declared its own, and overwriting would silently pick
    // between two claims the link refuses out loud.
    func bounded(by bounds: [Name: [Name]]) -> Signature {
        guard !bounds.isEmpty else { return self }

        return Signature(
            receiver: receiver,
            parameters: parameters.map { parameter in
                Parameter(
                    name: parameter.name,
                    type: parameter.type?.bounded(by: bounds),
                    candidates: parameter.candidates,
                    description: parameter.description
                )
            },
            returns: returns?.bounded(by: bounds)
        )
    }
}

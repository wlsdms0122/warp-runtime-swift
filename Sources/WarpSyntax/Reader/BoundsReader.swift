//
//  BoundsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// The signature-level `bounds:` key, which contracts each type parameter is
// bounded by, declared once where the parameter's name lives:
//
//   bounds { N "Standard.Numeric" }
//   parameters [ { name "of" type "some N" } { name "value" type "some N" } ]
//
// The slots name the parameter and the signature says what the name answers, so
// one bound is one claim however many slots mention the name.
struct BoundsReader {
    // MARK: - Property
    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // The contracts each type parameter's bound names. `steps` are where
    // `bounds` stands.
    func bounds(
        _ written: [Name: String]?,
        in notation: Notation,
        at steps: [Place.Step]
    ) throws -> [Name: Set<Name>] {
        // A bound is the names of contracts, one or several joined with `&`,
        // read the way a slot's `&` is.
        var named: [Name: Set<Name>] = [:]

        for (parameter, bound) in (written ?? [:]).sorted(by: { one, other in one.key < other.key }) {
            do {
                named[parameter] = try TypeReader.contracts(bound, in: notation)
            } catch let refused as TypeFormError {
                throw ReadingError(
                    "bounds bind '\(parameter)' to '\(bound)': \(refused.message)",
                    at: steps + [.key(parameter.spelling)]
                )
            }
        }

        return named
    }

    // MARK: - Private
}

//
//  BoundsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// What a signature holds to contracts beyond its own type parameters: an
// associated type of one, under the signature-level `bounds:` key, keyed by
// its label:
//
//   bounds { "C.Item" "Hashable" }
//   parameters [ { name "of" type "some C: Lib.Container" } ]
//
// A type parameter is bounded where its slots first name it. An associated
// type is not introduced by the signature, so its bound is said here, beside
// what `sameTypes` says of it.
struct BoundsReader {
    // MARK: - Property
    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // The contracts each label's bound names. `steps` are where `bounds`
    // stands.
    func bounds(
        _ written: [Name: String]?,
        in notation: Notation,
        at steps: [Place.Step]
    ) throws -> [Name: Set<Name>] {
        // A bound is the names of contracts, one or several joined with `&`,
        // read the way a slot's `&` is.
        var named: [Name: Set<Name>] = [:]

        for (label, bound) in (written ?? [:]).sorted(by: { one, other in one.key < other.key }) {
            guard label.associated != nil else {
                throw ReadingError(
                    "bounds '\(label)' under `bounds`, and a type parameter is bounded where the signature's slots"
                        + " first name it, `some \(label): \(bound)`. `bounds` holds an associated type, `\(label).Item`",
                    at: steps + [.key(label.spelling)]
                )
            }

            do {
                named[label] = try TypeReader.contracts(bound, in: notation)
            } catch let refused as TypeFormError {
                throw ReadingError(
                    "bounds bind '\(label)' to '\(bound)': \(refused.message)",
                    at: steps + [.key(label.spelling)]
                )
            }
        }

        return named
    }

    // MARK: - Private
}

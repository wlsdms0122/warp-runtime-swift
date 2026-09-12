//
//  BoundsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// The signature-level `bounds:` key, which constraint each type parameter is
// bounded by, declared once where the parameter's name lives:
//
//   bounds: { N: Numeric }
//   parameters: { of: some N, value: some N }
//
// The slots name the parameter and the signature says what the name admits, so
// one bound is one claim however many slots mention the name.
enum BoundsReader {
    // The signature with its bounds applied, and the check that every bound
    // names a parameter some slot mentions. A bound on a name nobody wrote
    // binds nothing, which is a claim the author should hear about where they
    // wrote it.
    static func apply(
        _ bounds: [String: String]?,
        to signature: Signature,
        at steps: [Place.Step]
    ) throws -> Signature {
        guard let bounds, !bounds.isEmpty else { return signature }

        // A bound is only ever a name (the membership lives in a declaration,
        // not in a signature) so a type here is refused where it was written
        // rather than surfacing later as a name nothing declares. The same
        // predicate the slot's `some T` spelling is held to.
        for (parameter, constraint) in bounds.sorted(by: { $0.key < $1.key }) {
            guard TypeReader.isName(constraint) else {
                throw ReadingError(
                    "bounds bind '\(parameter)' to"
                        + " '\(constraint)', which is not a constraint's name."
                        + " A membership is declared, never written in a"
                        + " signature",
                    at: steps
                )
            }
        }

        let named = try bounds.named(at: steps).mapValues { constraint in try Name.read(constraint, at: steps) }
        let bounded = signature.bounded(by: named)

        var mentioned: [Name: Set<Name>] = [:]
        bounded.parameterConstraints(into: &mentioned)

        let unwritten = named.keys
            .filter { name in mentioned[name] == nil }
            .sorted()

        guard unwritten.isEmpty else {
            throw ReadingError(
                "bounds name"
                    + " \(unwritten.map(\.spelling).joined(separator: ", ")), and no slot writes"
                    + " `some \(unwritten.first?.spelling ?? "")`. A bound rides on a"
                    + " parameter some slot mentions",
                at: steps
            )
        }

        return bounded
    }
}

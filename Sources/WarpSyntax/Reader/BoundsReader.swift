//
//  BoundsReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// The signature-level `bounds:` key — which constraint each type parameter is
// bounded by, declared once where the parameter's name lives:
//
//   bounds: { N: Numeric }
//   parameters: { of: some N, value: some N }
//
// The slots name the parameter and the signature says what the name admits, so
// one bound is one claim however many slots mention the name.
enum BoundsReader {
    // The signature with its bounds applied, and the check that every bound
    // names a parameter some slot mentions — a bound on a name nobody wrote
    // binds nothing, which is a claim the author should hear about where they
    // wrote it.
    static func apply(
        _ bounds: [String: String]?,
        to signature: Signature,
        at codingPath: [any CodingKey]
    ) throws -> Signature {
        guard let bounds, !bounds.isEmpty else { return signature }

        // A bound is only ever a name — the membership lives in a declaration,
        // not in a signature — so a shape here is refused where it was written
        // rather than surfacing later as a name nothing declares. The same
        // predicate the slot's `some T` spelling is held to.
        for (parameter, constraint) in bounds.sorted(by: { $0.key < $1.key }) {
            guard TypeReader.isName(constraint) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: codingPath,
                        debugDescription: "bounds bind '\(parameter)' to"
                            + " '\(constraint)', which is not a constraint's name"
                            + " — a membership is declared, never written in a"
                            + " signature"
                    )
                )
            }
        }

        let bounded = signature.bounded(by: bounds)

        var mentioned: [String: Set<String>] = [:]
        bounded.parameterConstraints(into: &mentioned)

        let unwritten = bounds.keys
            .filter { name in mentioned[name] == nil }
            .sorted()

        guard unwritten.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "bounds name"
                        + " \(unwritten.joined(separator: ", ")), and no slot writes"
                        + " `some \(unwritten.first ?? "")` — a bound rides on a"
                        + " parameter some slot mentions"
                )
            )
        }

        return bounded
    }
}

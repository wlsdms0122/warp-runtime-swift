//
//  LoweredType+Arity.swift
//  Warp
//
//  Created by JSilver on 9/24/26.
//

import Foundation

// Whether a number of arguments handed by position fits a procedure type. The
// one statement of the rule every call is held to: a call written against a
// declaration, a value applied, and a send a host procedure declared.
extension LoweredType {
    // Nil where the count fits, and where this is no procedure type or one
    // that says nothing about what it takes.
    func arityMismatch(handing count: Int, in table: LoweredTypeTable) -> ArityMismatch? {
        guard case let .procedure(parameters?, _, _, _) = self else { return nil }

        guard count <= parameters.count else { return .tooMany(takes: parameters.count) }

        let missing = parameters.indices.dropFirst(count)
            .filter { position in parameters[position].mustBeGiven(in: table) }

        return missing.isEmpty ? nil : .missing(positions: missing)
    }
}

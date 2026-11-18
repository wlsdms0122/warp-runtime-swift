//
//  Builder+ExpressionType.swift
//  WarpSyntax
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Warp

// Asking the build about a place in the keys a document writes it with.
public extension Builder {
    // What the expression at `place` was judged to hold by a build of
    // `modules` against `laid`, `place` being the value WARP-65 names a place
    // by: `Place.value`. Nil where the build judged no expression there. A
    // refusal the build meets before the walk judging the body reaches the
    // place refuses this, and one it meets after leaves the answer standing.
    func expressionType(at place: Value, of modules: [Module], against laid: Laid) async throws -> ExpressionType? {
        try await expressionType(where: { judged in judged.value == place }, of: modules, against: laid)
    }
}

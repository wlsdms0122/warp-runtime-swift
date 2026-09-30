//
//  Module+Logic.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

public extension Module {
    static let logic = bundled(nativeLogic, with: "logic")

    private static let nativeLogic = Module(
        unchecked: Draft(
            description: "Equality, negation, the connectives and choosing a value.",
            procedures: [
                "std.logic.equal": Procedure(
                    description: "Whether two values are the same.",
                    signature: Signature(of: EqualQuery.self, returns: .bool),
                    implementation: .query(EqualQuery())
                )
            ]
        ),
        builtin: true
    )
}

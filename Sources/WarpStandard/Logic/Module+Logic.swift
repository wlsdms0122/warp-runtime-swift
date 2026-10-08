//
//  Module+Logic.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

public extension Module {
    static let logic = bundled(nativeLogic, with: "logic")

    private static let nativeLogic = Module(
        unchecked: Draft(
            description: "Equality.",
            procedures: [
                "Standard.Logic.equal": Procedure(
                    description: "Whether two values are the same.",
                    signature: Signature(of: EqualQuery.self, returns: .bool),
                    implementation: .query(EqualQuery())
                )
            ]
        ),
        builtin: true
    )
}

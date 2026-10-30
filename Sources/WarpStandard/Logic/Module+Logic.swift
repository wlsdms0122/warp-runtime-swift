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
            procedures: [
                "Standard.Logic.equal": Procedure(
                    signature: Signature(
                        of: EqualQuery.self,
                        returns: .bool,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(EqualQuery())
                )
            ]
        ),
        builtin: true
    )
}

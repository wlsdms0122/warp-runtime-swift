//
//  Module+Math.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

public extension Module {
    static let math = bundled(nativeMath, with: "math")

    private static let nativeMath = Module(
        unchecked: Draft(
            procedures: [
                "Standard.Math.floored": Procedure(
                    signature: Signature(
                        of: FlooredQuery.self,
                        returns: .int,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(FlooredQuery())
                ),
                "Standard.Math.rounded": Procedure(
                    signature: Signature(
                        of: RoundedQuery.self,
                        returns: .int,
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(RoundedQuery())
                )
            ]
        ),
        builtin: true
    )
}

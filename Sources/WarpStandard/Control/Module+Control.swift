//
//  Module+Control.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

public extension Module {
    // Procedures about whether a body goes on, rather than about what it computes.
    static let control: [Module] = [nativeControl]

    private static let nativeControl = Module(
        unchecked: Draft(
            procedures: [
                "Standard.Control.abort": Procedure(
                    signature: Signature(
                        of: AbortQuery.self,
                        returns: .never,
                        failing: .these([Aborted.type]),
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(AbortQuery())
                )
            ]
        ),
        builtin: true
    )
}

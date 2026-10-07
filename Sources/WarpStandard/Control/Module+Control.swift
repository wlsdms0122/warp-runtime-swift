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
            description: "Failing on purpose instead of answering.",
            procedures: [
                "Standard.Control.abort": Procedure(
                    description: "Fails on purpose with a message, which an attempt around it catches.",
                    signature: Signature(of: AbortQuery.self, returns: .never),
                    implementation: .query(AbortQuery())
                )
            ]
        ),
        builtin: true
    )
}

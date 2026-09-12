//
//  Module+Control.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

public extension Module {
    // Procedures about whether a body goes on, rather than about what it computes.
    // The other bundles are named for what they read (truths, numbers, text,
    // containers) and this one reads nothing.
    static let control = try! Module(
        description: "Leaving instead of answering.",
        procedures: [
            "std.control.abort": Procedure(
                description: "Refuses with a message, which an attempt around it catches.",
                signature: Signature(of: AbortQuery.self, receiver: .of, returns: .never),
                implementation: .query(AbortQuery())
            )
        ]
    )
}

//
//  Module+Shouting.swift
//  WarpTestSupport
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

// Vocabulary is modules, so a test that needs a procedure beyond the standard ones
// declares one and puts it in the link.
public extension Module {
    static let shouting = try! Module(
        procedures: [
            "app.shout": Procedure(
                signature: Signature(of: ShoutEffect.self, returns: .string),
                implementation: .effect(ShoutEffect())
            )
        ]
    )
}

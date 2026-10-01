//
//  Module+Testing.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// A caller registers on both sides: the key in the notation's registry, the
// declaration in a module. The split is the point. One says how a document
// spells it, the other says what answers.
extension Module {
    static let testing = try! Module(
        procedures: [
            "test.fail": Procedure(
                signature: Signature(of: FailEffect.self),
                implementation: .effect(FailEffect())
            )
        ]
    )
}

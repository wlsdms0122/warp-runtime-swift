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

// The procedure a fixture calls to fail on purpose, recoverably or not.
extension Module {
    static let testing = try! Module(
        procedures: [
            "Test.fail": Procedure(
                signature: Signature(
                    of: FailEffect.self,
                    returns: .any,
                    failing: .these([TestRecoverableFailure.type]),
                    isolation: .isolated
                ),
                implementation: .effect(FailEffect())
            )
        ]
    )
}

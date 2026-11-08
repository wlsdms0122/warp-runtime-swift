//
//  Module+Fixture.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp
import WarpTestSupport

// Vocabulary is modules, so a test that needs a procedure declares one and puts it
// in the link.
extension Module {
    // A procedure that returns a value from a box it keeps between calls, and
    // says so. Two bodies calling it meet in that box.
    static let ticketing = try! Module(
        procedures: [
            "App.ticket": Procedure(
                signature: Signature(returns: .int, constness: .const),
                implementation: .query(TicketQuery())
            )
        ]
    )

    static let failing = try! Module(
        procedures: [
            "App.fail": Procedure(
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

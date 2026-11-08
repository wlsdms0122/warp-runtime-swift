//
//  SuppliedEffect.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

// A procedure a case asked for that runs, through the door that reaches
// outside the run. What it returns is the case's, as `SuppliedQuery`'s is.
struct SuppliedEffect<Parameters: ParameterSet>: Effect, SendsWhereMade {
    // MARK: - Property
    let answers: Value

    // What the case declares it sends, which it never calls.
    let declared: [SuppliedSend]

    var sends: [(position: Int, selector: Name, handing: Int)] {
        declared.map { send in (position: send.position, selector: send.selector, handing: send.handing) }
    }

    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        answers
    }

    // MARK: - Private
}

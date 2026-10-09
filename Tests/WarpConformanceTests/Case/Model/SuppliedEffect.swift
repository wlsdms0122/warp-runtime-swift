//
//  SuppliedEffect.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

// A procedure a case asked for that runs, through the door that reaches
// outside the run. What it answers is the case's, as `SuppliedQuery`'s is.
struct SuppliedEffect<Parameters: ParameterSet>: Effect {
    // MARK: - Property
    let answers: Value
    let isolated: Bool
    let failing: Failing

    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        answers
    }

    // MARK: - Private
}

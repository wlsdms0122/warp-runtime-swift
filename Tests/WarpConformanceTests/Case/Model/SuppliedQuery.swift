//
//  SuppliedQuery.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

// A procedure a case asked for that answers without running. What it answers is
// the case's, and it is the same every time: a case asks what a declaration
// permits, not what arithmetic does.
struct SuppliedQuery<Parameters: ParameterSet>: Query {
    // MARK: - Property
    let answers: Value
    let isolated: Bool
    let failing: Failing

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        answers
    }

    // MARK: - Private
}

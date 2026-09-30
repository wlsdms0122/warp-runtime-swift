//
//  TestRecoverableFailure.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    let message = "the world did not cooperate"

    let type = "test"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

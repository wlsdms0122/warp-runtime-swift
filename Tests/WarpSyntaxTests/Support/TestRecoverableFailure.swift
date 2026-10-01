//
//  TestRecoverableFailure.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    let message = "the world did not cooperate"

    var type: String { Self.type }

    static let type = "test"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

//
//  TestRecoverableFailure.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    let message = "the world did not cooperate"

    var type: String { Self.type }

    static let type = "test"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

//
//  TestRecoverableFailure.swift
//  WarpTestSupport
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

public struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    public let message = "the world did not cooperate"

    public var type: String { Self.type }

    public static let type = "test"

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // MARK: - Private
}

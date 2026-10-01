//
//  TestFatalError.swift
//  WarpTestSupport
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

public struct TestFatalError: WarpError {
    // MARK: - Property
    public let message = "author mistake"

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // MARK: - Private
}

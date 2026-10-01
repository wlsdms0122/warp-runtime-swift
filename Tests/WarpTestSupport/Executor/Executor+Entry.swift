//
//  Executor+Entry.swift
//  WarpTestSupport
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A test's image runs from the test's entry unless the test names another.
public extension Executor {
    func run(_ image: Image, arguments: [Name: Value] = [:]) async throws -> Value {
        try await run(image, entry: entryName, arguments: arguments)
    }
}

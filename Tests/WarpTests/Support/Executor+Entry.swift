//
//  Executor+Entry.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

// A test's image runs from the test's entry unless the test names another.
extension Executor {
    func run(_ image: Image, arguments: [Name: Value] = [:]) async throws -> Value {
        try await run(image, entry: entryName, arguments: arguments)
    }
}

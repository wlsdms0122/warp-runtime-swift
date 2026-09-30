//
//  Executor+Entry.swift
//  WarpStandardTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp
import WarpStandard

// A test's image runs from the test's entry unless the test names another.
extension Executor {
    func run(_ image: Image, arguments: [Name: Value] = [:]) async throws -> Value {
        try await run(image, entry: entryName, arguments: arguments)
    }
}

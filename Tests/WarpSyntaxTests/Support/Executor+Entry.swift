//
//  Executor+Entry.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/30/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

// A test's image runs from the test's entry unless the test names another.
extension Executor {
    func run(_ image: Image, arguments: [Name: Value] = [:]) async throws -> Value {
        try await run(image, entry: entryName, arguments: arguments)
    }
}

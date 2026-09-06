//
//  AppendingEffect.swift
//  WarpStandard
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Warp

// Writing one element onto the end of an array, in place. The array is handed
// as a variable's path and written through it, so the caller's variable holds
// the longer array when the word answers. An effect and not a query, because
// a write is what it does.
struct AppendingEffect: Effect {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation) async throws -> Value {
        guard case let .array(elements) = try invocation.held("to") else {
            throw ExecutionError("append writes onto an array, and 'to' holds something else")
        }

        try invocation.write("to", .array(elements + [invocation["value"]]))

        return .null
    }

    // MARK: - Private
}

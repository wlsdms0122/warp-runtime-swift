//
//  Settlement.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The arguments as they cross a declaration's boundary: each settled value
// standing at its parameter's position, under the names the declaration gave
// those positions. A native reads one by name, and the name is found along
// the declaration rather than hashed: a declaration has a few parameters,
// and a word asks for each once.
struct Settlement: Sendable {
    // MARK: - Property
    let names: [String]
    let values: [Value?]

    // MARK: - Initializer
    init(names: [String], values: [Value?]) {
        self.names = names
        self.values = values
    }

    // Arguments given by name, in name order.
    init(_ arguments: [String: Value]) {
        let sorted = arguments.sorted { left, right in left.key < right.key }

        self.names = sorted.map { entry in entry.key }
        self.values = sorted.map { entry in entry.value }
    }

    // MARK: - Public
    // What a named argument holds. An argument nobody wrote and one written as
    // null are the same fact here, the same as they are everywhere else.
    subscript(name: String) -> Value {
        guard let position = names.firstIndex(of: name) else { return .null }

        return values[position] ?? .null
    }

    // MARK: - Private
}

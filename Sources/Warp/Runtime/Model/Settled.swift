//
//  Settled.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The arguments as settling left them: each value standing at its
// parameter's position, beside the declaration of that position. A native
// reads one by name, and the name is found along the declaration rather than
// hashed: a declaration has a few parameters, and a word asks for each once.
struct Settled: Sendable {
    // MARK: - Property
    let parameters: [(name: String, parameter: Parameter)]
    let values: [Value?]

    // MARK: - Initializer
    // The values a row's boundary settled, one per parameter of the row.
    init(by callee: Linked, values: [Value?]) {
        precondition(callee.parameters.count == values.count)

        self.parameters = callee.parameters
        self.values = values
    }

    // Arguments a caller offers by name with no declaration behind them, so
    // each stands as undeclared: what `any` says.
    init(offered arguments: [String: Value]) {
        self.parameters = arguments.keys.map { name in (name: name, parameter: Parameter()) }
        self.values = arguments.keys.map { name in arguments[name] }
    }

    // MARK: - Public
    // What a named argument holds. An argument nobody wrote and one written as
    // null are the same fact here, the same as they are everywhere else.
    subscript(name: String) -> Value {
        guard let position = position(of: name) else { return .null }

        return values[position] ?? .null
    }

    // Where a name stands, or nil for a name the declaration lacks.
    func position(of name: String) -> Int? {
        parameters.firstIndex { declared, _ in declared == name }
    }

    // MARK: - Private
}

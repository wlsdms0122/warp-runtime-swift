//
//  Settled.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The arguments as a row's boundary left them: one value per parameter of
// the row, standing at that parameter's position. The row is the owner of
// the positions, so a name is read by asking the row where it stands. A
// declaration has a few parameters and a word asks for each once, so the
// name is found along the declaration rather than hashed.
struct Settled: Sendable {
    // MARK: - Property
    let callee: Linked
    let values: [Value?]

    // MARK: - Initializer
    init(by callee: Linked, values: [Value?]) {
        self.callee = callee
        self.values = values
    }

    // MARK: - Public
    // What a named argument holds. An argument nobody wrote and one written as
    // null are the same fact here, the same as they are everywhere else.
    subscript(name: String) -> Value {
        guard let position = position(of: name) else { return .null }

        return values[position] ?? .null
    }

    // Where a name stands in the row, or nil for a name the row lacks.
    func position(of name: String) -> Int? {
        callee.slots.firstIndex { slot in Name.same(slot.name, name) }
    }

    // MARK: - Private
}

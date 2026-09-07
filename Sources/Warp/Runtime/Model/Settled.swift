//
//  Settled.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The arguments as a row's boundary left them: one value per parameter of the
// row, standing at that parameter's position. Positions and no names, because
// the link owns where a parameter stands and a word reads the place its own
// key says.
struct Settled: Sendable {
    // MARK: - Property
    let values: [Value?]

    // MARK: - Initializer
    init(values: [Value?]) {
        self.values = values
    }

    // MARK: - Public
    // What the argument at a place holds. An argument nobody wrote and one
    // written as null are the same fact here, the same as they are everywhere
    // else, and so is a place this row does not have.
    subscript(position: Int) -> Value {
        guard values.indices.contains(position) else { return .null }

        return values[position] ?? .null
    }

    // MARK: - Private
}

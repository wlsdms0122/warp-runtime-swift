//
//  ArgumentList.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A call's arguments by position: one value per parameter of the row,
// standing at that parameter's position. Positions and no names, because the
// build owns where a parameter stands and a procedure reads the place its own
// key says.
struct ArgumentList: Sendable {
    // MARK: - Property
    let values: [Value?]

    // MARK: - Initializer
    init(values: [Value?]) {
        self.values = values
    }

    // MARK: - Public
    // What the argument at a place holds. A place handed in place holds no
    // value here, since its box is read through the hold, and it reads as
    // null the way a place this row does not have does.
    subscript(position: Int) -> Value {
        guard values.indices.contains(position) else { return .null }

        return values[position] ?? .null
    }

    // MARK: - Private
}

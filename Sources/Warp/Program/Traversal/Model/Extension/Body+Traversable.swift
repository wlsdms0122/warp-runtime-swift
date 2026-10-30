//
//  Body+Traversable.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Body: Traversable {
    // A statement is found under its own name (or, one run for its effect
    // alone, under its position, which is the only thing there is to call it)
    // and then under the construct it writes, the way a document nests it.
    func walk<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail,
        into found: inout [(Trail, Node)]
    ) {
        for (position, statement) in statements.enumerated() {
            let steps = statement.steps(at: position)

            found.append((steps.dropLast().reduce(trail, stepping), .statement(statement)))
            statement.expression.walk(at: steps.reduce(trail, stepping), stepping: stepping, into: &found)
        }
    }
}

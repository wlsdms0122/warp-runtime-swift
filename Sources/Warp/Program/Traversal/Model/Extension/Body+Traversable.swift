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
    func walked<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Node)] {
        statements.enumerated().flatMap { position, statement in
            let steps = statement.steps(at: position)
            let here = steps.dropLast().reduce(trail, stepping)

            return [(here, Node.statement(statement))]
                + statement.expression.walked(at: steps.reduce(trail, stepping), stepping: stepping)
        }
    }
}

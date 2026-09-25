//
//  Array+Statement.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension [Statement]: Traversable {}

public extension [Statement] {
    // A statement is found under its own name (or, one run for its effect
    // alone, under its position, which is the only thing there is to call it)
    // and then under the construct it writes, the way a document nests it.
    func walked<Trail>(
        at trail: Trail,
        stepping: (Trail, Place.Step) -> Trail
    ) -> [(Trail, Node)] {
        enumerated().flatMap { position, statement in
            let here = stepping(trail, .statement(name: statement.name?.spelling, at: position))

            return [(here, Node.statement(statement))]
                + statement.expression.walked(
                    at: stepping(here, .construct(statement.expression.construct)),
                    stepping: stepping
                )
        }
    }
}

extension [Statement] {
    // Whether every way through this sequence leaves. A sequence leaves when
    // one of its statements always leaves, because nothing after that one runs.
    public var alwaysLeaves: Bool {
        contains { statement in statement.expression.alwaysLeaves }
    }
}

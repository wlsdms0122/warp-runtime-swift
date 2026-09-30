//
//  Block+Reading.swift
//  WarpSyntax
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

extension Block {
    // The other adjacency the same rule names: a result runs after the body, so
    // a body that always leaves would never reach it. Held where a document's
    // body/result pair is joined (every reader that assembles the two comes
    // through here, the way every statement sequence comes through
    // `BodyReader`) so the pair rule cannot be forgotten one assembler at a
    // time.
    static func reading(
        body: Body,
        result: Expression?,
        at steps: [Place.Step]
    ) throws -> Block {
        if body.alwaysLeaves, result != nil {
            throw ReadingError(
                "result: nothing runs after leaving,"
                    + " and this result would never be reached",
                at: steps
            )
        }

        return Block(body: body, result: result)
    }
}

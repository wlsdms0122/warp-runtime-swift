//
//  TestSupport.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

// A statement that may fail and does not: a plain cast onto a type the value
// already fits. An `attempt` stands only over a body that can fail, so a test
// showing what a rescue does *not* catch puts one of these in the body.
func mayFail(_ name: Name = "checked") -> Statement {
    Statement(
        binding: .constant(name),
        expression: .cast(.literal(.null), as: .nullable(.int), optional: false)
    )
}

// MARK: - Conditions

// Walking a collection is a loop over its count, so a test writing one writes
// the type a notation spells `each` with: the round's index against the
// material's count, and the element read at that index.
func walking(
    _ material: Path,
    element: Name,
    round: Name = "walk",
    body: Body
) -> Warp.Expression {
    .loop(
        while: .call(
            Call(
                selector: "Standard.Comparable.lessThan",
                arguments: [
                    .reference([.key(round), .key("index")]),
                    .call(Call(selector: "Standard.Collection.count", arguments: [.reference(material)]))
                ]
            )
        ),
        body: Block(
            body: Body([
                Statement(
                    binding: .constant(element),
                    expression: .reference(material.appending(contentsOf: [.indexRef([.key(round), .key("index")])]))
                )
            ] + body.statements)
        )
    )
}

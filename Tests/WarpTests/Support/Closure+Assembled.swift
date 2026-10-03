//
//  Closure+Assembled.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

extension Closure {
    // A closure a caller assembles in Swift: no body a document spelled, no
    // captures, claiming nothing. What a slot that asks nothing takes.
    static func assembled(answering result: Value? = nil, in table: LoweredTypeTable = .empty) -> Closure {
        Closure(
            writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("assembled")),
            nth: 0,
            linked: Linked(
                label: "assembled",
                origin: 0,
                signature: Signature(),
                access: .internal,
                constness: .unstated,
                isolation: .unstated,
                failing: .unstated,
                handsBackAsDeclared: false,
                implementation: .body(
                    LoweredBody(instructions: [], result: result.map(Operation.literal)),
                    Frame(size: 0, parameters: [], variables: [], captures: [], names: [])
                ),
                foldable: true,
                in: table
            ),
            captured: []
        )
    }
}

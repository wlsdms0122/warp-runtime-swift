//
//  Closure+Assembled.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

extension Closure {
    // A closure a caller assembles in Swift: no body a document spelled, no
    // captures, claiming nothing.
    static func assembled() -> Closure {
        Closure(
            writer: Closure.Writer(document: .compiled(Compiled.Token()), name: "assembled"),
            nth: 0,
            linked: Linked(
                label: "assembled",
                origin: 0,
                signature: Signature(),
                access: .internal,
                constness: .unstated,
                isolation: .unstated,
                failing: .unstated,
                implementation: .body(
                    LoweredBody(instructions: [], result: nil),
                    Frame(size: 0, parameters: [], variables: [], captures: [], names: [])
                ),
                foldable: true,
                in: .empty
            ),
            captured: []
        )
    }
}

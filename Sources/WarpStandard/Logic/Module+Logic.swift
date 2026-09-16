//
//  Module+Logic.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

public extension Module {
    static let logic = bundled(nativeLogic, with: "logic")

    private static let nativeLogic = try! Module(
        description: "Equality, negation, the connectives and choosing a value.",
        procedures: [
            "std.logic.equal": Procedure(
                description: "Whether two values are the same.",
                signature: Signature(of: EqualQuery.self, receiver: .of, returns: .bool),
                implementation: .query(EqualQuery())
            ),
            // `and`/`or` rather than `all`/`any`: the connectives' universal
            // names, and they leave `all` free for `std.concurrent`, whose
            // meaning is the one everybody else calls `all`.
            "std.logic.select": Procedure(
                description: "What one of two sides answers, chosen by a truth.",
                signature: Signature(
                    of: SelectQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "Answer")
                ),
                implementation: .query(SelectQuery())
            )
        ]
    )
}

//
//  Module+Logic.swift
//  WarpStandard
//
//  Created by JSilver
//

import Foundation
import Warp

public extension Module {
    static let logic = try! Module(
        description: "Equality, negation, the connectives and choosing a value.",
        procedures: [
            "std.logic.equal": Procedure(
                description: "Whether two values are the same.",
                signature: Signature(of: EqualQuery.self, receiver: .of, returns: .bool),
                implementation: .query(EqualQuery())
            ),
            "std.logic.notEqual": Procedure(
                description: "Whether two values differ.",
                signature: Signature(of: NotEqualQuery.self, receiver: .of, returns: .bool),
                implementation: .query(NotEqualQuery())
            ),
            "std.logic.not": Procedure(
                description: "The opposite of a truth.",
                signature: Signature(of: NotQuery.self, receiver: .of, returns: .bool),
                implementation: .query(NotQuery())
            ),
            // `and`/`or` rather than `all`/`any`: the connectives' universal
            // names, and they leave `all` free for `std.concurrent`, whose
            // meaning is the one everybody else calls `all`.
            "std.logic.and": Procedure(
                description: "Whether every one answers true, asked until one does not.",
                signature: Signature(of: AndQuery.self, receiver: .of, returns: .bool),
                implementation: .query(AndQuery())
            ),
            "std.logic.or": Procedure(
                description: "Whether one answers true, asked until one does.",
                signature: Signature(of: OrQuery.self, receiver: .of, returns: .bool),
                implementation: .query(OrQuery())
            ),
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

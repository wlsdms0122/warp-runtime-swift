//
//  Module+Net.swift
//  WarpNet
//

import Foundation
import Warp

public extension Module {
    // HTTP. A request goes out and a response comes back, so both are effects.
    // The return value is one struct, `Net.Response`, whatever the status was: a
    // status the program does not like is the program's to judge. What fails
    // is the request itself, under `net_failed`.
    static func net() throws -> Module {
        try Module(
            types: [
                "Net.Response": .struct(["body": .string, "headers": .dictionary(key: .string, value: .string), "status": .int])
            ],
            procedures: [
                "Net.get": Procedure(
                    signature: Signature(of: GetEffect.self, returns: .named("Net.Response"), failing: .these([NetFailed.type])),
                    implementation: .effect(GetEffect())
                ),
                "Net.post": Procedure(
                    signature: Signature(of: PostEffect.self, returns: .named("Net.Response"), failing: .these([NetFailed.type])),
                    implementation: .effect(PostEffect())
                )
            ]
        )
    }
}

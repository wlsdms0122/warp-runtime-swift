//
//  Module+Host.swift
//  warpx
//

import Foundation
import Warp

extension Module {
    // What this host lends a program: a log, a keyed store and tickets. Every
    // one reaches outside the run, so every one is an effect.
    static func host() throws -> Module {
        try Module(
            types: [
                "Host.Ticket": .struct(["id": .int])
            ],
            procedures: [
                "Host.issue": Procedure(
                    signature: Signature(of: IssueEffect.self, returns: .named("Host.Ticket")),
                    implementation: IssueEffect()
                ),
                "Host.redeem": Procedure(
                    signature: Signature(of: RedeemEffect.self, returns: .int),
                    implementation: RedeemEffect()
                ),
                "Host.log": Procedure(
                    signature: Signature(of: LogEffect.self, returns: .null),
                    implementation: LogEffect()
                ),
                "Host.put": Procedure(
                    signature: Signature(of: PutEffect.self, returns: .null),
                    implementation: PutEffect()
                ),
                "Host.get": Procedure(
                    signature: Signature(of: GetEffect.self, returns: .any),
                    implementation: GetEffect()
                )
            ]
        )
    }
}

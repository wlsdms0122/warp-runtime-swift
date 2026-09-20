//
//  Module+Concurrent.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

public extension Module {
    // Procedures that run closures at once. Vocabulary rather than grammar, so
    // running things concurrently is something a caller grants by linking this
    // bundle. A program whose caller left it out cannot fan out at all.
    static let concurrent = bundled(nativeConcurrent, with: "concurrent")

    private static let nativeConcurrent = try! Module(
        description: "Running closures at once.",
        constraints: [
            // What a fan-out is handed: closures under keys, or closures in
            // order. Two types and no third, which is what a membership says
            // and what `any` could not.
            "std.concurrent.Pieces": [
                .array(.procedure(nil, .unstated, .isolated)),
                .dictionary(.procedure(nil, .unstated, .isolated))
            ]
        ],
        procedures: [
            // `std.collection.first` and `std.concurrent.first` are two names
            // in one link, so concurrency shows at the call site.
            //
            // What comes back is `any` because it is shaped like what went in,
            // and a membership names a set of types rather than tying one of
            // them to another. `map`, whose types are single, says it all.
            "std.concurrent.all": Procedure(
                description: "Runs every closure, and answers every answer."
                    + " A record's under its keys, an array's in its order."
                    + " A failure fails the whole procedure, with every piece's"
                    + " failure reported.",
                signature: Signature(of: AllEffect.self, receiver: .of, returns: .any),
                implementation: .effect(AllEffect())
            ),
            "std.concurrent.first": Procedure(
                description: "Runs every closure, answers the first success and"
                    + " asks the rest to stop. Which one wins is timing's. The"
                    + " one fact here that is.",
                signature: Signature(of: FirstEffect.self, receiver: .of, returns: .any),
                implementation: .effect(FirstEffect())
            )
        ],
        builtin: true
    )
}

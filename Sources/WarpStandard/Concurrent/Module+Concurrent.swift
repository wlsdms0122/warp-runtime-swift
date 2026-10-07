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
    // running things concurrently is something a host grants by linking this
    // bundle. A program whose host left it out cannot fan out at all.
    static let concurrent = bundled(nativeConcurrent, with: "concurrent")

    private static let nativeConcurrent = Module(
        unchecked: Draft(
            description: "Running closures at once.",
            constraints: [
                // What a fan-out is handed: closures under keys, or closures in
                // order. Two types and no third, which is what a membership says
                // and what `Any` could not.
                "Standard.Concurrent.Pieces": [
                    .array(.procedure(nil, .unstated, .isolated)),
                    .dictionary(.procedure(nil, .unstated, .isolated))
                ]
            ],
            procedures: [
                // `Standard.Collection.first` and `Standard.Concurrent.first` are two names
                // in one link, so concurrency shows at the call site.
                //
                // What comes back is `Any` because it is shaped like what went in,
                // and a membership names a set of types rather than tying one of
                // them to another. `map`, whose types are single, says it all.
                "Standard.Concurrent.all": Procedure(
                    description: "Runs every closure, and answers every answer."
                        + " A record's under its keys, an array's in its order."
                        + " A failure fails the whole procedure, with every piece's"
                        + " failure reported.",
                    signature: Signature(of: AllEffect.self, returns: .any),
                    implementation: .effect(AllEffect())
                ),
                "Standard.Concurrent.first": Procedure(
                    description: "Runs every closure, answers the first success and"
                        + " asks the rest to stop. Which one wins is the one fact"
                        + " here timing decides.",
                    signature: Signature(of: FirstEffect.self, returns: .any),
                    implementation: .effect(FirstEffect())
                )
            ]
        ),
        builtin: true
    )
}

//
//  Module+Concurrent.swift
//  WarpStandard
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Warp

public extension Module {
    // Words that run closures at once. Vocabulary rather than grammar, so
    // running things concurrently is something a caller grants by linking this
    // bundle. A program whose caller left it out cannot fan out at all.
    static let concurrent = try! Module(
        description: "Running closures at once.",
        procedures: [
            // `std.collection.first` and `std.concurrent.first` are two names
            // in one link, so concurrency shows at the call site.
            //
            // `of` and what comes back are declared `any` because both take two
            // shapes (a record of closures or an array of them) and a union is
            // not a thing a type here can say. The precision is not lost so
            // much as unsayable; `map`, whose shapes are single, says it all.
            "std.concurrent.all": Procedure(
                description: "Runs every closure, and answers every answer."
                    + " A record's under its keys, an array's in its order."
                    + " A failure fails the whole word, with every piece's"
                    + " failure reported.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .any
                ),
                implementation: .effect(ConcurrentEffect(.all))
            ),
            "std.concurrent.first": Procedure(
                description: "Runs every closure, answers the first success and"
                    + " asks the rest to stop. Which one wins is timing's. The"
                    + " one fact here that is.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .any
                ),
                implementation: .effect(ConcurrentEffect(.first))
            ),
            "std.concurrent.map": Procedure(
                description: "Runs one closure once per element, offering each"
                    + " call `item` and `index`, and answers in the"
                    + " collection's order.",
                signature: Signature(
                    receiver: "over",
                    parameters: [
                        "over": Parameter(type: .array(.parameter(name: "Element"))),
                        "by": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: [
                                        "item": Parameter(type: .parameter(name: "Element")),
                                        "index": Parameter(type: .int)
                                    ],
                                    returns: .parameter(name: "Answer")
                                ),
                                .unstated,
                                .isolated
                            )
                        )
                    ],
                    returns: .array(.parameter(name: "Answer"))
                ),
                implementation: .effect(ConcurrentEffect(.map))
            )
        ]
    )
}

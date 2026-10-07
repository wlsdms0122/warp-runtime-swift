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
            procedures: [
                // `Standard.Collection.first` and `Standard.Concurrent.first` are two names
                // in one link, so concurrency shows at the call site.
                //
                // The pieces come in order or under keys, and each way has a
                // name of its own, so what comes back is said in the type:
                // the answers in order, or under the pieces' keys.
                "Standard.Concurrent.all": Procedure(
                    description: "Runs every closure, and answers every answer in the closures' order."
                        + " A failure fails the whole procedure, with every piece's failure reported.",
                    signature: Signature(parameters: [pieces(in: TypeExpression.array)], returns: .array(.any)),
                    implementation: .effect(AllEffect(answering: "Standard.Concurrent.all"))
                ),
                "Standard.Concurrent.allKeyed": Procedure(
                    description: "Runs every closure, and answers every answer under the closure's key."
                        + " A failure fails the whole procedure, with every piece's failure reported.",
                    signature: Signature(parameters: [pieces(in: TypeExpression.dictionary)], returns: .dictionary(.any)),
                    implementation: .effect(AllEffect(answering: "Standard.Concurrent.allKeyed"))
                ),
                "Standard.Concurrent.first": Procedure(
                    description: "Runs every closure, answers the first success and"
                        + " asks the rest to stop. Which one wins is the one fact"
                        + " here timing decides.",
                    signature: Signature(parameters: [pieces(in: TypeExpression.array)], returns: .any),
                    implementation: .effect(FirstEffect(answering: "Standard.Concurrent.first"))
                ),
                "Standard.Concurrent.firstKeyed": Procedure(
                    description: "Runs every closure under a key, answers the first success and"
                        + " asks the rest to stop. Which one wins is the one fact"
                        + " here timing decides.",
                    signature: Signature(parameters: [pieces(in: TypeExpression.dictionary)], returns: .any),
                    implementation: .effect(FirstEffect(answering: "Standard.Concurrent.firstKeyed"))
                )
            ]
        ),
        builtin: true
    )

    // The pieces a fan-out runs, held in a list or under keys: closures that
    // touch nothing another piece could touch at once.
    private static func pieces(in holding: (TypeExpression) -> TypeExpression) -> Parameter {
        Parameter(name: "pieces", type: holding(.procedure(nil, .unstated, .isolated)))
    }
}

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
                    signature: Signature(
                        parameters: [pieces(in: TypeExpression.array)],
                        returns: .array(answer),
                        failing: failing,
                        isolation: .isolated
                    ),
                    implementation: .effect(AllEffect(answering: "Standard.Concurrent.all"))
                ),
                "Standard.Concurrent.allKeyed": Procedure(
                    description: "Runs every closure, and answers every answer under the closure's key."
                        + " A failure fails the whole procedure, with every piece's failure reported.",
                    signature: Signature(
                        parameters: [pieces(in: keyed)],
                        returns: keyed(answer),
                        failing: failing,
                        isolation: .isolated,
                        bounds: keys
                    ),
                    implementation: .effect(AllEffect(answering: "Standard.Concurrent.allKeyed"))
                ),
                "Standard.Concurrent.first": Procedure(
                    description: "Runs every closure, answers the first success and"
                        + " asks the rest to stop. Which one wins is the one fact"
                        + " here timing decides.",
                    signature: Signature(
                        parameters: [pieces(in: TypeExpression.array)],
                        returns: answer,
                        failing: failing,
                        isolation: .isolated
                    ),
                    implementation: .effect(FirstEffect(answering: "Standard.Concurrent.first"))
                ),
                "Standard.Concurrent.firstKeyed": Procedure(
                    description: "Runs every closure under a key, answers the first success and"
                        + " asks the rest to stop. Which one wins is the one fact"
                        + " here timing decides.",
                    signature: Signature(
                        parameters: [pieces(in: keyed)],
                        returns: answer,
                        failing: failing,
                        isolation: .isolated,
                        bounds: keys
                    ),
                    implementation: .effect(FirstEffect(answering: "Standard.Concurrent.firstKeyed"))
                )
            ]
        ),
        builtin: true
    )

    // What every piece answers, one type the call fills from the pieces, so
    // what comes back is said in the type.
    private static let answer = TypeExpression.parameter(name: "Answer")

    // Pieces and answers under keys: one type the call fills from the
    // pieces' map, held to what a key of any map answers.
    private static func keyed(_ held: TypeExpression) -> TypeExpression {
        .dictionary(key: .parameter(name: "Key"), value: held)
    }

    private static let keys: [Name: Set<Name>] = ["Key": [TypeSpelling.hashable]]

    // Every recoverable failure a piece raises is gathered into one.
    private static let failing = Failing.these([ConcurrentFailed.type])

    // The pieces a fan-out runs, held in a list or under keys: closures that
    // touch nothing another piece could touch at once, each answering the
    // one type the call fills.
    private static func pieces(in holding: (TypeExpression) -> TypeExpression) -> Parameter {
        Parameter(name: "pieces", type: holding(.procedure(ProcedureType(returns: answer, failing: .anything), .unstated, .isolated)))
    }
}

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
            procedures: [
                // `Standard.Collection.first` and `Standard.Concurrent.first` are two names
                // in one link, so concurrency shows at the call site.
                //
                // The pieces come in order or under keys, and each way has a
                // name of its own, so what comes back is said in the type:
                // the return values in order, or under the pieces' keys.
                "Standard.Concurrent.all": Procedure(
                    signature: Signature(
                        parameters: [pieces(in: TypeExpression.array)],
                        returns: .array(result),
                        failing: failing,
                        isolation: .isolated
                    ),
                    implementation: .effect(AllEffect(implementing: "Standard.Concurrent.all"))
                ),
                "Standard.Concurrent.allKeyed": Procedure(
                    signature: Signature(
                        parameters: [pieces(in: keyed)],
                        returns: keyed(result),
                        failing: failing,
                        isolation: .isolated,
                        bounds: keys
                    ),
                    implementation: .effect(AllEffect(implementing: "Standard.Concurrent.allKeyed"))
                ),
                "Standard.Concurrent.first": Procedure(
                    signature: Signature(
                        parameters: [pieces(in: TypeExpression.array)],
                        returns: result,
                        failing: failing,
                        isolation: .isolated
                    ),
                    implementation: .effect(FirstEffect(implementing: "Standard.Concurrent.first"))
                ),
                "Standard.Concurrent.firstKeyed": Procedure(
                    signature: Signature(
                        parameters: [pieces(in: keyed)],
                        returns: result,
                        failing: failing,
                        isolation: .isolated,
                        bounds: keys
                    ),
                    implementation: .effect(FirstEffect(implementing: "Standard.Concurrent.firstKeyed"))
                )
            ]
        ),
        builtin: true
    )

    // What every piece returns, one type the call fills from the pieces, so
    // what comes back is said in the type.
    private static let result = TypeExpression.parameter(name: "Result")

    // Pieces and return values under keys: one type the call fills from the
    // pieces' dictionary, held to what a key of any dictionary conforms to.
    private static func keyed(_ held: TypeExpression) -> TypeExpression {
        .dictionary(key: .parameter(name: "Key"), value: held)
    }

    private static let keys: [Name: Set<Name>] = ["Key": [TypeSpelling.hashable]]

    // Every recoverable failure a piece raises is gathered into one.
    private static let failing = Failing.these([ConcurrentFailed.type])

    // The pieces a fan-out runs, held in a list or under keys: closures that
    // touch nothing another piece could touch at once, each returning the
    // one type the call fills.
    private static func pieces(in holding: (TypeExpression) -> TypeExpression) -> Parameter {
        Parameter(name: "pieces", type: holding(.procedure(ProcedureType(returns: result, failing: .anything), .unstated, .isolated)))
    }
}

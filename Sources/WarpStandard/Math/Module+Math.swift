//
//  Module+Math.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

public extension Module {
    static let math = bundled(nativeMath, with: "math")

    private static let nativeMath = try! Module(
        description: "Arithmetic, and the ordering of numbers and strings.",
        procedures: [
            "std.math.plus": Procedure(
                description: "The sum, whole where both sides are.",
                signature: Signature(
                    of: PlusQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "N", constraints: ["std.Numeric"])
                ),
                implementation: .query(PlusQuery())
            ),
            "std.math.minus": Procedure(
                description: "The difference.",
                signature: Signature(
                    of: MinusQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "N", constraints: ["std.Numeric"])
                ),
                implementation: .query(MinusQuery())
            ),
            "std.math.times": Procedure(
                description: "The product.",
                signature: Signature(
                    of: TimesQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "N", constraints: ["std.Numeric"])
                ),
                implementation: .query(TimesQuery())
            ),
            "std.math.dividedBy": Procedure(
                description: "The quotient, which is not generally whole.",
                signature: Signature(of: DividedByQuery.self, receiver: .of, returns: .double),
                implementation: .query(DividedByQuery())
            ),
            "std.math.remainder": Procedure(
                description: "What is left of a whole division.",
                signature: Signature(
                    of: RemainderQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "N", constraints: ["std.Numeric"])
                ),
                implementation: .query(RemainderQuery())
            ),
            "std.math.floored": Procedure(
                description: "The whole number at or below this one.",
                signature: Signature(of: FlooredQuery.self, receiver: .of, returns: .int),
                implementation: .query(FlooredQuery())
            ),
            "std.math.rounded": Procedure(
                description: "The nearest whole number.",
                signature: Signature(of: RoundedQuery.self, receiver: .of, returns: .int),
                implementation: .query(RoundedQuery())
            ),
            "std.math.lessThan": Procedure(
                description: "Whether this orders before another.",
                signature: Signature(of: LessThanQuery.self, receiver: .of, returns: .bool),
                implementation: .query(LessThanQuery())
            )
        ],
        builtin: true
    )
}

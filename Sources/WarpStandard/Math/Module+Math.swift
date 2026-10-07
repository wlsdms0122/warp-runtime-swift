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

    private static let nativeMath = Module(
        unchecked: Draft(
            description: "Arithmetic, and the ordering of numbers and strings.",
            procedures: [
                "Standard.Math.plus": Procedure(
                    description: "The sum, whole where both sides are.",
                    signature: Signature(
                        of: PlusQuery.self,
                        returns: .parameter(name: "N", constraints: ["Standard.Numeric"])
                    ),
                    implementation: .query(PlusQuery())
                ),
                "Standard.Math.minus": Procedure(
                    description: "The difference.",
                    signature: Signature(
                        of: MinusQuery.self,
                        returns: .parameter(name: "N", constraints: ["Standard.Numeric"])
                    ),
                    implementation: .query(MinusQuery())
                ),
                "Standard.Math.times": Procedure(
                    description: "The product.",
                    signature: Signature(
                        of: TimesQuery.self,
                        returns: .parameter(name: "N", constraints: ["Standard.Numeric"])
                    ),
                    implementation: .query(TimesQuery())
                ),
                "Standard.Math.dividedBy": Procedure(
                    description: "The quotient, which is not generally whole.",
                    signature: Signature(of: DividedByQuery.self, returns: .double),
                    implementation: .query(DividedByQuery())
                ),
                "Standard.Math.remainder": Procedure(
                    description: "What is left of a division truncated toward zero.",
                    signature: Signature(
                        of: RemainderQuery.self,
                        returns: .parameter(name: "N", constraints: ["Standard.Numeric"])
                    ),
                    implementation: .query(RemainderQuery())
                ),
                "Standard.Math.floored": Procedure(
                    description: "The whole number at or below a number.",
                    signature: Signature(of: FlooredQuery.self, returns: .int),
                    implementation: .query(FlooredQuery())
                ),
                "Standard.Math.rounded": Procedure(
                    description: "The nearest whole number.",
                    signature: Signature(of: RoundedQuery.self, returns: .int),
                    implementation: .query(RoundedQuery())
                ),
                "Standard.Math.lessThan": Procedure(
                    description: "Whether one orders before the other.",
                    signature: Signature(of: LessThanQuery.self, returns: .bool),
                    implementation: .query(LessThanQuery())
                )
            ]
        ),
        builtin: true
    )
}

//
//  Module+Math.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

public extension Module {
    static let math = try! Module(
        description: "Arithmetic, and the ordering of numbers and strings.",
        procedures: [
            "std.math.plus": Procedure(
                description: "The sum, whole where both sides are.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Numeric")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
                    ],
                    returns: .parameter(name: "N", constraint: "std.Numeric")
                ),
                implementation: .query(ArithmeticQuery(.plus))
            ),
            "std.math.minus": Procedure(
                description: "The difference.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Numeric")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
                    ],
                    returns: .parameter(name: "N", constraint: "std.Numeric")
                ),
                implementation: .query(ArithmeticQuery(.minus))
            ),
            "std.math.times": Procedure(
                description: "The product.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Numeric")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
                    ],
                    returns: .parameter(name: "N", constraint: "std.Numeric")
                ),
                implementation: .query(ArithmeticQuery(.times))
            ),
            "std.math.dividedBy": Procedure(
                description: "The quotient, which is not generally whole.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Numeric")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
                    ],
                    returns: .double
                ),
                implementation: .query(ArithmeticQuery(.dividedBy))
            ),
            "std.math.remainder": Procedure(
                description: "What is left of a whole division.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Numeric")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
                    ],
                    returns: .parameter(name: "N", constraint: "std.Numeric")
                ),
                implementation: .query(ArithmeticQuery(.remainder))
            ),
            "std.math.min": Procedure(
                description: "The smaller of two of a kind, by the one order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Comparable")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Comparable"))
                    ],
                    returns: .parameter(name: "N", constraint: "std.Comparable")
                ),
                implementation: .query(ComparisonQuery(.min))
            ),
            "std.math.max": Procedure(
                description: "The larger of two of a kind, by the one order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "N", constraint: "std.Comparable")),
                        "value": Parameter(type: .parameter(name: "N", constraint: "std.Comparable"))
                    ],
                    returns: .parameter(name: "N", constraint: "std.Comparable")
                ),
                implementation: .query(ComparisonQuery(.max))
            ),
            "std.math.absolute": Procedure(
                description: "The number without its sign.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))],
                    returns: .parameter(name: "N", constraint: "std.Numeric")
                ),
                implementation: .query(NumberQuery(.absolute))
            ),
            "std.math.floored": Procedure(
                description: "The whole number at or below this one.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .number)],
                    returns: .int
                ),
                implementation: .query(NumberQuery(.floored))
            ),
            "std.math.rounded": Procedure(
                description: "The nearest whole number.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .number)],
                    returns: .int
                ),
                implementation: .query(NumberQuery(.rounded))
            ),
            "std.math.lessThan": Procedure(
                description: "Whether this orders before another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "T", constraint: "std.Comparable")),
                        "value": Parameter(type: .parameter(name: "T", constraint: "std.Comparable"))
                    ],
                    returns: .bool
                ),
                implementation: .query(ComparisonQuery(.lessThan))
            ),
            "std.math.greaterThan": Procedure(
                description: "Whether this orders after another.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .parameter(name: "T", constraint: "std.Comparable")),
                        "value": Parameter(type: .parameter(name: "T", constraint: "std.Comparable"))
                    ],
                    returns: .bool
                ),
                implementation: .query(ComparisonQuery(.greaterThan))
            )
        ]
    )
}

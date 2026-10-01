//
//  MathTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpStandard

@Suite("What std.math answers")
struct MathTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a divisor of zero refuses rather than taking the process")
    func divisionByZeroRefuses() async throws {
        // Given. Both are Swift traps if the answer is taken rather than
        // judged, and each arrives at run time
        let asks: [(Name, Value, Value)] = [
            ("std.math.remainder", .int(5), .int(0)),
            ("std.math.dividedBy", .int(5), .int(0)),
            ("std.math.dividedBy", .double(5), .double(0))
        ]

        for (procedure, subject, operand) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .call(Call(selector: procedure, arguments: [.literal(subject), .literal(operand)]))
                    )
                ]
            )

            // When / Then
            await #expect(throws: ExecutionError.self, "\(procedure) took the process") {
                try await run(sut)
            }
        }
    }

    @Test("arithmetic off the int's edge is a fault, not a wrap")
    func wholeArithmeticOverflowFaults() async throws {
        // Given. Each of these falls off the edge of the int, and the
        // language stops rather than answering a number the digits do not say
        let asks: [(Name, Value, Value)] = [
            ("std.math.times", .int(Int.max), .int(2)),
            ("std.math.plus", .int(Int.max), .int(1)),
            ("std.math.minus", .int(Int.min), .int(1))
        ]

        func asking(_ procedure: Name, _ subject: Value, _ operand: Value) async throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .call(Call(selector: procedure, arguments: [.literal(subject), .literal(operand)]))
                    )
                ]
            )
        }

        for (procedure, subject, operand) in asks {
            // When / Then
            await #expect(throws: ExecutionError.self, "\(procedure) answered") {
                try await run(asking(procedure, subject, operand))
            }
        }

        // `Int.min remainder -1` trips the hardware's division, but the
        // remainder itself is 0. An answer an int holds, so it answers.
        await #expect(try await run(asking("std.math.remainder", .int(Int.min), .int(-1))) == .int(0))
    }

    @Test("fraction arithmetic with no finite answer refuses rather than answering infinity")
    func fractionArithmeticRefusesRatherThanEscapes() async throws {
        // Given. Each of these reaches past the largest fraction, and
        // infinity is a value no document can carry
        let asks: [(Name, Double, Double)] = [
            ("std.math.plus", 1e308, 1e308),
            ("std.math.minus", -1e308, 1e308),
            ("std.math.times", 1e308, 10.0)
        ]

        for (procedure, subject, operand) in asks {
            // When / Then
            await #expect {
                try await run(sending(procedure, .double(subject), .double(operand)))
            } throws: { error in
                "\(error)".contains("no finite answer")
            }
        }
    }

    @Test("a whole number widens to a fraction on either side")
    func wholeNumbersWiden() async throws {
        // When / Then
        await #expect(try await run(sending("std.math.plus", .int(1), .double(0.5))) == .double(1.5))
        await #expect(try await run(sending("std.math.plus", .double(0.5), .int(1))) == .double(1.5))
    }

    @Test("a quotient is a fraction even between wholes")
    func aQuotientIsAFraction() async throws {
        // Given. `dividedBy` never answers an int
        func divided(_ left: Int, _ right: Int) async throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .call(Call(
                            selector: "std.math.dividedBy",
                            arguments: [.literal(.int(left)), .literal(.int(right))]
                        ))
                    )
                ]
            )
        }

        // When / Then
        await #expect(try await run(divided(6, 2)) == .double(3.0))
        await #expect(try await run(divided(7, 2)) == .double(3.5))
        await #expect(try await run(divided(Int.max, Int.max)) == .double(1.0))

        // The quotient is binary64's own: each whole operand widens first (the
        // same widening every mixed operation performs) and the division rounds
        // once more. 2^53 + 1 widens to 2^53, and the answer is the widened
        // pair's, bit for bit.
        #expect(
            try await run(divided(9_007_199_254_740_993, 3))
                == .double(9_007_199_254_740_992.0 / 3.0)
        )
    }

    @Test("rounding and magnitude stop at the int's edge")
    func roundingPastTheIntFaults() async throws {
        // Given. A fraction whose whole part is past the int has no
        // int to answer, and the int's own minimum has no magnitude an int
        // holds. The refusal names the overflow, not a missing whole answer.
        // The two reasons are different facts.
        let asks: [(Name, Value)] = [
            ("std.math.floored", .double(1e30)),
            ("std.math.rounded", .double(1e30)),
            ("std.math.absolute", .int(Int.min))
        ]

        for (procedure, subject) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .call(Call(selector: procedure, arguments: [.literal(subject)]))
                    )
                ]
            )

            // When / Then
            await #expect {
                try await run(sut)
            } throws: { error in
                "\(error)".contains("overflows int")
            }
        }
    }

    @Test("whole numbers stay whole, and a quotient does not")
    func arithmeticKeepsItsRepresentation() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("sum"), expression: .call(Call(
                            selector: "std.math.plus",
                            arguments: [.literal(.int(2)), .literal(.int(3))]
                        ))
                        ),
                        Statement(binding: .constant("product"), expression: .call(Call(
                            selector: "std.math.times",
                            arguments: [.literal(.int(4)), .literal(.double(2.5))]
                        ))
                        ),
                        Statement(binding: .constant("quotient"), expression: .call(Call(
                            selector: "std.math.dividedBy",
                            arguments: [.literal(.int(7)), .literal(.int(2))]
                        ))
                        )
                    ],
                    result: .record([
                        "product": reference("product"),
                        "quotient": reference("quotient"),
                        "sum": reference("sum")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(sut)

        // Then
        #expect(answer == .dictionary(["product": .double(10), "quotient": .double(3.5), "sum": .int(5)]))
    }

    @Test("an ordering answers a condition")
    func comparisonReadsAsACondition() async throws {
        // Given. A conditional asks a bool and `lessThan` answers one, so
        // ordering needs no grammar of its own
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "n", type: .int)]),
                    body: [
                        Statement(binding: .variable("verdict"), expression: .literal(.string(""))),
                        Statement(
                            expression: .conditional(
                                .call(Call(
                                    selector: "std.math.lessThan",
                                    arguments: [reference("n"), .literal(.int(10))]
                                )),
                                then: [
                                    Statement(
                                        binding: .assignment([.key("verdict")]),
                                        expression: .literal(.string("small"))
                                    )
                                ],
                                else: [
                                    Statement(
                                        binding: .assignment([.key("verdict")]),
                                        expression: .literal(.string("large"))
                                    )
                                ]
                            )
                        )
                    ],
                    result: reference("verdict")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["n": .int(3)]) == .string("small"))
        #expect(try await run(sut, arguments: ["n": .int(30)]) == .string("large"))
    }

    @Test("bytes do not order")
    func bytesDoNotOrder() async throws {
        // Given. Bytes are an array, and `std.Comparable` admits numbers and
        // strings, not collections. A literal is a reading the build can
        // judge, so the refusal lands before the run.
        let sut = Warp.Expression.call(
            Call(selector: "std.math.lessThan", arguments: [.literal(.bytes([0x01])), .literal(.bytes([0x02]))])
        )

        // When / Then
        await #expect {
            try await answer(of: [Statement(binding: .constant("probe"), expression: sut)], result: reference("probe"))
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("a whole and a fraction meet exactly at every size")
    func wholeAndFractionMeetExactly() async throws {
        // Given. 2^53 + 1 rounds to 2^53 in binary64, so a judgment that
        // converts would call two different worths the same. Worth does not
        // follow the rounding, in any consumer of the one order.
        let above = Value.int(9007199254740993)
        let below = Value.double(9007199254740992.0)

        // When / Then
        #expect(!above.matches(below))
        #expect(Value.int(9007199254740992).matches(below))
        #expect(Value.order(above, below) == .orderedDescending)
        #expect(Value.order(below, above) == .orderedAscending)
        #expect(Value.order(.int(-2), .double(-2.5)) == .orderedDescending)
        #expect(Value.order(.int(.max), .double(0x1p63)) == .orderedAscending)
        #expect(Value.order(.int(.min), .double(-0x1p63)) == .orderedSame)
        #expect(Value.order(.int(0), .double(.nan)) == nil)

        // max answers `rhs` on a tie, so `above` coming back is the int
        // winning rather than a conversion flattening the two into a tie.
        let picked = try await run(
            Procedure(
                body: [],
                result: .call(
                    Call(selector: "std.math.max", arguments: [.literal(above), .literal(below)])
                )
            )
        )

        #expect(picked == above)
    }

    @Test("min and max order the way the comparison procedures do")
    func minAndMaxOrderLikeTheComparisons() async throws {
        // Given. Strings order lexicographically under Comparable, which bounds
        // `min` the way it bounds `lessThan`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [],
                    result: .call(Call(
                        selector: "std.math.min",
                        arguments: [.literal(.string("b")), .literal(.string("a"))]
                    ))
                )
            ]
        )

        // When / Then
        let answer = try await run(sut)

        #expect(answer == .string("a"))
    }

    // MARK: - Public
    // MARK: - Private
    // An entry that sends one procedure a subject and an operand.
    private func sending(_ procedure: Name, _ subject: Value, _ operand: Value) throws -> Module {
        try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: procedure, arguments: [.literal(subject), .literal(operand)]))
                )
            ]
        )
    }
}

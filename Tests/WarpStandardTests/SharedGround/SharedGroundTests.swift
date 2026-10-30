//
//  SharedGroundTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/7/26.
//

import Foundation
import Testing
import Warp
import WarpStandard
import WarpTestSupport

@Suite("What the shared ground returns")
struct SharedGroundTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a divisor of zero refuses rather than taking the process")
    func divisionByZeroRefuses() async throws {
        // Given. A divisor of zero has no result, an integer one traps where
        // the result is taken rather than judged, and each arrives at run time
        let asks: [(Name, Value, Value)] = [
            ("Standard.Numeric.remainder", .int(5), .int(0)),
            ("Standard.Numeric.dividedBy", .int(5), .int(0)),
            ("Standard.Numeric.dividedBy", .double(5), .double(0))
        ]

        for (procedure, subject, operand) in asks {
            // When / Then
            await #expect(throws: ExecutionError.self, "\(procedure) took the process") {
                try await run(sending(procedure, subject, operand))
            }
        }
    }

    @Test("arithmetic off the Int's edge is a fault, not a wrap")
    func intArithmeticOverflowFaults() async throws {
        // Given. Each of these falls off the edge of the int, and the
        // language stops rather than returning a number the digits do not say
        let asks: [(Name, Value, Value)] = [
            ("Standard.Numeric.times", .int(Int.max), .int(2)),
            ("Standard.Numeric.plus", .int(Int.max), .int(1)),
            ("Standard.Numeric.minus", .int(Int.min), .int(1))
        ]

        for (procedure, subject, operand) in asks {
            // When / Then
            await #expect(throws: ExecutionError.self, "\(procedure) returned") {
                try await run(sending(procedure, subject, operand))
            }
        }

        // `Int.min remainder -1` trips the hardware's division, but the
        // remainder itself is 0. The result is one an int holds, so it returns.
        #expect(try await run(sending("Standard.Numeric.remainder", .int(Int.min), .int(-1))) == .int(0))
    }

    @Test("Double arithmetic with no finite result refuses rather than returning infinity")
    func doubleArithmeticRefusesRatherThanEscapes() async throws {
        // Given. Each of these reaches past the largest floating-point number,
        // and infinity is a value no document can carry
        let asks: [(Name, Double, Double)] = [
            ("Standard.Numeric.plus", 1e308, 1e308),
            ("Standard.Numeric.minus", -1e308, 1e308),
            ("Standard.Numeric.times", 1e308, 10.0)
        ]

        for (procedure, subject, operand) in asks {
            // When / Then
            await #expect {
                try await run(sending(procedure, .double(subject), .double(operand)))
            } throws: { error in
                "\(error)".contains("holds a floating-point number with no finite value")
            }
        }
    }

    @Test("an integer literal beside a Double is the Double it names, on either side")
    func anIntegerLiteralBesideADoubleIsTheDouble() async throws {
        // When / Then
        #expect(try await run(sending("Standard.Numeric.plus", .int(1), .double(0.5))) == .double(1.5))
        #expect(try await run(sending("Standard.Numeric.plus", .double(0.5), .int(1))) == .double(1.5))
    }

    @Test("a quotient is a Double even between Ints")
    func aQuotientIsADouble() async throws {
        // Given. `dividedBy` never returns an int
        func divided(_ left: Int, _ right: Int) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .double),
                        body: [
                            returning(.call(Call(
                                selector: "Standard.Numeric.dividedBy",
                                arguments: [.literal(.int(left)), .literal(.int(right))]
                            )))
                        ]
                    )
                ]
            )
        }

        // When / Then
        #expect(try await run(divided(6, 2)) == .double(3.0))
        #expect(try await run(divided(7, 2)) == .double(3.5))
        #expect(try await run(divided(Int.max, Int.max)) == .double(1.0))

        // The quotient is binary64's own: each integer operand reads as the
        // floating-point number nearest it first and the division rounds once
        // more. 2^53 + 1 reads as 2^53, and the result is that pair's, bit for
        // bit.
        #expect(
            try await run(divided(9_007_199_254_740_993, 3))
                == .double(9_007_199_254_740_992.0 / 3.0)
        )
    }

    @Test("Ints stay Int, and a quotient does not")
    func arithmeticKeepsItsRepresentation() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .constant("sum"), expression: .call(Call(
                            selector: "Standard.Numeric.plus",
                            arguments: [.literal(.int(2)), .literal(.int(3))]
                        ))
                        ),
                        Statement(binding: .constant("product"), expression: .call(Call(
                            selector: "Standard.Numeric.times",
                            arguments: [.literal(.int(4)), .literal(.double(2.5))]
                        ))
                        ),
                        Statement(binding: .constant("quotient"), expression: .call(Call(
                            selector: "Standard.Numeric.dividedBy",
                            arguments: [.literal(.int(7)), .literal(.int(2))]
                        ))
                        ),
                        returning(dictionary([
                            "product": reference("product"),
                            "quotient": reference("quotient"),
                            "sum": reference("sum")
                        ]))
                    ]
                )
            ]
        )

        // When
        let returned = try await run(sut)

        // Then
        #expect(returned == .dictionary(["product": .double(10), "quotient": .double(3.5), "sum": .int(5)]))
    }

    @Test("an ordering reads as a condition")
    func comparisonReadsAsACondition() async throws {
        // Given. A conditional asks a bool and `lessThan` returns one, so
        // ordering needs no grammar of its own
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "n", type: .int)], returns: .string),
                    body: [
                        Statement(binding: .variable("verdict"), expression: .literal(.string(""))),
                        Statement(
                            expression: .conditional(
                                .call(Call(
                                    selector: "Standard.Comparable.lessThan",
                                    arguments: [reference("n"), .literal(.int(10))]
                                )),
                                then: [
                                    Statement(
                                        binding: .assignment([.name("verdict")]),
                                        expression: .literal(.string("small"))
                                    )
                                ],
                                else: [
                                    Statement(
                                        binding: .assignment([.name("verdict")]),
                                        expression: .literal(.string("large"))
                                    )
                                ]
                            )
                        ),
                        returning(reference("verdict"))
                    ]
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["n": .int(3)]) == .string("small"))
        #expect(try await run(sut, arguments: ["n": .int(30)]) == .string("large"))
    }

    @Test("bytes do not order")
    func bytesDoNotOrder() async throws {
        // Given. Bytes are an array, and `Standard.Comparable` is claimed for
        // numbers and strings, not collections. A literal is a reading the
        // build can judge, so the refusal lands before the run.
        let sut = Warp.Expression.call(
            Call(selector: "Standard.Comparable.lessThan", arguments: [.literal(.bytes([0x01])), .literal(.bytes([0x02]))])
        )

        // When / Then
        await #expect {
            try await returned(of: [Statement(binding: .constant("probe"), expression: sut)], returning: reference("probe"))
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'Array' conforms to")
        }
    }

    @Test("an Int and a Double meet exactly at every size")
    func intAndDoubleMeetExactly() async throws {
        // Given. 2^53 + 1 rounds to 2^53 in binary64, so a judgement that
        // converts would call two different worths the same
        let above = Value.int(9007199254740993)
        let below = Value.double(9007199254740992.0)

        // When / Then
        #expect(!above.matches(below))
        #expect(!below.matches(above))
        #expect(Value.int(9007199254740992).matches(below))
        #expect(!Value.int(-2).matches(.double(-2.5)))
        #expect(!Value.int(.max).matches(.double(0x1p63)))
        #expect(Value.int(.min).matches(.double(-0x1p63)))
        #expect(!Value.int(0).matches(.double(.nan)))
    }

    // MARK: - Public
    // MARK: - Private
    // An entry that sends one procedure a subject and an operand.
    private func sending(_ procedure: Name, _ subject: Value, _ operand: Value) throws -> Module {
        try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any, failing: .anything),
                    body: [returning(.call(Call(selector: procedure, arguments: [.literal(subject), .literal(operand)])))]
                )
            ]
        )
    }
}

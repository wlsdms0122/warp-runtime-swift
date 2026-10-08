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
import WarpTestSupport

@Suite("What Standard.Math answers")
struct MathTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("rounding and magnitude stop at the Int's edge")
    func roundingPastTheIntFaults() async throws {
        // Given. A fraction whose whole part is past the int has no
        // int to answer, and the int's own minimum has no magnitude an int
        // holds. The refusal names the overflow, not a missing whole answer.
        // The two reasons are different facts.
        let asks: [(Name, Value)] = [
            ("Standard.Math.floored", .double(1e30)),
            ("Standard.Math.rounded", .double(1e30)),
            ("Standard.Math.absolute", .int(Int.min))
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
                "\(error)".contains("overflows Int")
            }
        }
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
                        selector: "Standard.Math.min",
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
}

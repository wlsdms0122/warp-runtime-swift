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

@Suite("What Standard.Math returns")
struct MathTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("rounding and magnitude stop at the Int's edge")
    func roundingPastTheIntFaults() async throws {
        // Given. A floating-point number whose whole part is past the int has
        // no int to return, and the int's own minimum has no magnitude an int
        // holds. The refusal names the overflow, not a missing integer to return.
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
                        signature: Signature(returns: .int),
                        body: [returning(.call(Call(selector: procedure, arguments: [.literal(subject)])))]
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
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Math.min",
                            arguments: [.literal(.string("b")), .literal(.string("a"))]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        let returned = try await run(sut)

        #expect(returned == .string("a"))
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  LogicTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpStandard
import WarpTestSupport

@Suite("What Standard.Logic answers")
struct LogicTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a connective leaves the rest unasked once the answer is decided")
    func connectivesShortCircuit() async throws {
        // Given. The later side divides by zero, which refuses when it is
        // asked. `all` is decided by the first false, so it never is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .bool, failing: .anything),
                    body: [
                        Statement(binding: .constant("verdict"), expression: every(
                                equals(.literal(.int(1)), .literal(.int(2))),
                                equals(
                                    .call(Call(
                                        selector: "Standard.Numeric.dividedBy",
                                        arguments: [.literal(.int(1)), .literal(.int(0))]
                                    )),
                                    .literal(.int(0))
                                )
                            )
                        )
                    ],
                    result: reference("verdict")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .bool(false))
    }

    @Test("two spellings of one text are one value")
    func stringsCompareAsAPersonReads() async throws {
        // Given. Unicode writes `é` two ways, and the two are different bytes.
        // A name is held to one spelling (normal form C), but a string value
        // arrives from the world spelled however the world spelled it, so
        // equality reads the text the way a person does, not the bytes.
        let sut = Warp.Expression.call(
            Call(
                selector: "Standard.Logic.equal",
                arguments: [.literal(.string("caf\u{E9}")), .literal(.string("cafe\u{301}"))]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .bool(true))
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  TextTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpStandard

@Suite("What std.text answers")
struct TextTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("text spells a whole number the same way at every size and depth")
    func textSpellsWholeNumbersUniformly() async throws {
        // Given. The quotes must not change with the value's size: a number is
        // a number wherever it sits, and only text wears quotes
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "std.text.text",
                        arguments: [
                            .literal(.array([
                                .int(1),
                                .int(Int.max),
                                .string("9223372036854775807")
                            ]))
                        ]
                    ))
                )
            ]
        )

        // When / Then
        #expect(
            try await run(sut)
                == .string("[1,9223372036854775807,\"9223372036854775807\"]")
        )
    }

    @Test("text procedures compose the way a document writes them")
    func textProceduresCompose() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "line", type: .string)]),
                    body: [
                        Statement(binding: .constant("parts"), expression: .call(Call(
                            selector: "std.text.split",
                            arguments: [reference("line"), .literal(.string(","))]
                        ))
                        ),
                        Statement(binding: .constant("rejoined"), expression: .call(Call(
                            selector: "std.text.joined",
                            arguments: [reference("parts"), .literal(.string(" / "))]
                        ))
                        ),
                        Statement(binding: .constant("fixed"), expression: .call(Call(
                            selector: "std.text.replacing",
                            arguments: [reference("rejoined"), .literal(.string("b")), .literal(.string("B"))]
                        ))
                        )
                    ],
                    result: reference("fixed")
                )
            ]
        )

        // When
        let answer = try await run(sut, arguments: ["line": .string("a,b,c")])

        // Then
        #expect(answer == .string("a / B / c"))
    }

    // MARK: - Public
    // MARK: - Private
}

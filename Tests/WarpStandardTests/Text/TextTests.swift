//
//  TextTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpStandard
import WarpTestSupport

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

    @Test("a codec converts in the encoding its argument names")
    func aCodecReadsItsEncodingArgument() async throws {
        // Given. The slot checks the name before a run; this asks the codec
        // directly, so the name reaches it unchecked
        let decoded = DecodedQuery()
        let encoded = EncodedQuery()

        // When / Then
        #expect(
            try await decoded.evaluate(Question(
                arguments: ["bytes": .bytes([104]), "encoding": .string("utf8")]
            )) == .string("h")
        )
        #expect(
            try await encoded.evaluate(Question(
                arguments: ["text": .string("h"), "encoding": .string("utf8")]
            )) == .bytes([104])
        )

        await #expect(throws: ExecutionError.self) {
            try await decoded.evaluate(Question(
                arguments: ["bytes": .bytes([104]), "encoding": .string("utf16")]
            ))
        }
        await #expect(throws: ExecutionError.self) {
            try await encoded.evaluate(Question(
                arguments: ["text": .string("h"), "encoding": .string("utf16")]
            ))
        }
    }

    @Test("decoded and encoded are two directions of one named mapping")
    func decodedAndEncodedRoundTrip() async throws {
        // Given
        func procedure(_ selector: Name, on subject: Value) async throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .call(Call(selector: selector, arguments: [.literal(subject), .literal(.string("utf8"))]))
                    )
                ]
            )
        }

        // When / Then
        #expect(try await run(procedure("std.text.decoded", on: .bytes([104, 105]))) == .string("hi"))
        #expect(try await run(procedure("std.text.encoded", on: .string("hi"))) == .bytes([104, 105]))

        // Bytes carry no promise of being text, and a completed guess is a
        // text nobody sent.
        await #expect {
            try await run(procedure("std.text.decoded", on: .bytes([0xff])))
        } throws: { error in
            "\(error)".contains("std.text.decoded asks bytes that are text")
        }
    }

    @Test("an encoding the procedures do not name refuses at the build")
    func anUnknownEncodingRefuses() async throws {
        // Given. The enum names the encodings, and a constant is judged at the
        // build
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "std.text.decoded",
                        arguments: [.literal(.bytes([104])), .literal(.string("utf16"))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'utf16' not in enum")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

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

@Suite("What Standard.Text answers")
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
                        selector: "Standard.Text.text",
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
                            selector: "Standard.Text.split",
                            arguments: [reference("line"), .literal(.string(","))]
                        ))
                        ),
                        Statement(binding: .constant("rejoined"), expression: .call(Call(
                            selector: "Standard.Text.joined",
                            arguments: [reference("parts"), .literal(.string(" / "))]
                        ))
                        ),
                        Statement(binding: .constant("fixed"), expression: .call(Call(
                            selector: "Standard.Text.replacing",
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
        // Given. The encoding arrives as a value, so the codec judges the name
        // where it runs
        func codec(_ selector: Name, taking subject: TypeExpression) -> Procedure {
            Procedure(
                signature: Signature(parameters: [
                    Parameter(name: "subject", type: subject),
                    Parameter(name: "encoding", type: .string)
                ]),
                body: [],
                result: .call(Call(selector: selector, arguments: [reference("subject"), reference("encoding")]))
            )
        }

        let decoded = codec("Standard.Text.decoded", taking: .array(.int))
        let encoded = codec("Standard.Text.encoded", taking: .string)

        // When / Then
        #expect(
            try await run(decoded, arguments: ["subject": .bytes([104]), "encoding": .string("utf8")])
                == .string("h")
        )
        #expect(
            try await run(encoded, arguments: ["subject": .string("h"), "encoding": .string("utf8")])
                == .bytes([104])
        )

        await #expect(throws: ExecutionError.self) {
            try await run(decoded, arguments: ["subject": .bytes([104]), "encoding": .string("utf16")])
        }
        await #expect(throws: ExecutionError.self) {
            try await run(encoded, arguments: ["subject": .string("h"), "encoding": .string("utf16")])
        }
    }

    @Test("decoded and encoded are two directions of one named mapping")
    func decodedAndEncodedRoundTrip() async throws {
        // Given
        func procedure(_ selector: Name, on subject: Value) throws -> Module {
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
        #expect(try await run(procedure("Standard.Text.decoded", on: .bytes([104, 105]))) == .string("hi"))
        #expect(try await run(procedure("Standard.Text.encoded", on: .string("hi"))) == .bytes([104, 105]))

        // Bytes carry no promise of being text, and a completed guess is a
        // text nobody sent.
        await #expect {
            try await run(procedure("Standard.Text.decoded", on: .bytes([0xff])))
        } throws: { error in
            "\(error)".contains("Standard.Text.decoded asks an Array<Int> that is text")
        }
    }

    @Test("an encoding the procedures do not have, written as a constant, refuses at the run")
    func anUnknownConstantEncodingRefusesAtTheRun() async throws {
        // Given. The procedure names the encodings it has where it refuses
        // another, and says so when it runs
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Text.decoded",
                        arguments: [.literal(.bytes([104])), .literal(.string("utf16"))]
                    ))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            "\(error)".contains("Standard.Text.decoded asks the name of an encoding it has (utf8), and 'utf16' is not one")
        }
    }

    @Test("an encoding the procedures do not have, arriving at the run, refuses there")
    func anUnknownEncodingRefusesAtTheRun() async throws {
        // Given. The name is what a variable holds
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [Statement(binding: .variable("named"), expression: .literal(.string("utf16")))],
                    result: .call(Call(
                        selector: "Standard.Text.encoded",
                        arguments: [.literal(.string("hi")), .reference([.name("named")])]
                    ))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            !(error is BuildError)
                && "\(error)".contains("Standard.Text.encoded asks the name of an encoding it has (utf8), and 'utf16' is not one")
        }
    }

    @Test("a list holding what is no byte, written as a constant, refuses at the run by the element")
    func aListHoldingNoByteRefusesAtTheRun() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Text.decoded",
                        arguments: [.array([.literal(.int(104)), .literal(.int(300))]), .literal(.string("utf8"))]
                    ))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            "\(error)".contains("Standard.Text.decoded asks an Array<Int> of bytes, and [1] is 300, which is no whole number from 0 to 255")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

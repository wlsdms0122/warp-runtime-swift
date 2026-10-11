//
//  ReturnTypeTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

@Suite("What a procedure returns")
struct ReturnTypeTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a declared answer is held to its declaration before the caller sees it")
    func answerIsHeldToItsDeclaration() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .constant("counted"), expression: .literal(.int(3)))
                    ],
                    result: .reference([.name("counted")])
                )
            ]
        )

        // When
        let image = try await builder.build([sut])
        let answer = try await Executor().run(image)

        // Then. Held to the declared representation, not merely waved past
        #expect(answer == .int(3))
    }

    @Test("a body that answers something else is refused where both are written")
    func wrongReturnFails() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("counted"), expression: .literal(.int(3)))
                    ],
                    result: .reference([.name("counted")])
                )
            ]
        )

        // When / Then. The body and the declaration beside it are one
        // document's text, so nothing has to run to find them disagreeing
        await #expect {
            try await builder.build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("answers Int, and its declaration promises String")
        }
    }

    @Test("a return carrying something else is refused where it is written")
    func wrongReturnIsRefusedAtTheBuild() async throws {
        // Given. The result fits; a `return` on one way through does not.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            expression: .conditional(
                                .literal(.bool(true)),
                                then: [Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.string("x")))))],
                                else: nil
                            )
                        )
                    ],
                    result: .literal(.int(0))
                )
            ]
        )

        // When / Then. Two answers that disagree would join to `Any`, and
        // `Any` fits everything, so each is held on its own.
        let refusal = await #expect(throws: BuildError.self) {
            try await builder.build([sut])
        }

        #expect(refusal?.message.contains("declaration promises Int") == true)
    }

    @Test("a record literal answered where a declared record is promised takes the name, and a nameless value does not")
    func aLiteralAnsweredTakesTheDeclaredName() async throws {
        // Given. The same list written straight into the answer, and held
        // first by a name that says nothing of the record
        func module(answering result: Warp.Expression, holding body: Body = []) throws -> Module {
            try Module(
                types: ["Task": .record(["id": .string])],
                procedures: [
                    "entry": Procedure(
                        access: .public,
                        signature: Signature(returns: .array(.named("Task"))),
                        body: body,
                        result: result
                    )
                ]
            )
        }

        let written = try module(answering: .array([.record(["id": .literal(.string("a"))])]))
        let held = try module(
            answering: .reference([.name("made")]),
            holding: [Statement(binding: .constant("made"), expression: .array([.record(["id": .literal(.string("a"))])]))]
        )

        // When / Then. A literal is written where the promise stands, so it
        // is a `Task`; a name holds a list of nameless records, and a place
        // gives no value a name
        let image = try await builder.build([written])

        #expect(try await Executor().run(image) == .array([.record(Record(name: "Task", ["id": .string("a")]))]))

        await #expect {
            try await builder.build([held])
        } throws: { error in
            error is BuildError && "\(error)".contains("declaration promises Array<Task>")
        }
    }

    @Test("an answer naming a type nobody declared is refused at the build")
    func unknownReturnTypeIsABuildError() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        returns: .named("Nowhere")
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1)))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            _ = try await builder.build([sut])
        } throws: { error in
            error is BuildError && "\(error)".contains("names type 'Nowhere', which no module in this link declares")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

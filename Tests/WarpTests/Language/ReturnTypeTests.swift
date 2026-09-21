//
//  ReturnTypeTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A declaration said what it took and nothing about what came back, so the
// judgement this language makes before running stopped at the boundary it was
// easiest to make it at.
@Suite("What a procedure returns")
struct ReturnTypeTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a declared answer is settled before the caller sees it")
    func answerIsSettled() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .constant("counted"), expression: .literal(.int(3))
                        )
                    ],
                    result: .reference([.key("counted")])
                )
            ]
        )

        // When
        let image = try await builder.build([sut])
        let answer = try await Executor().run(image)

        // Then. Settled to the declared representation, not merely waved past
        #expect(answer == .int(3))

        // And a fraction is not that representation, whatever it is worth: a
        // declaration is about the type, not about which values happen to fit.
        let narrowing = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [Statement(binding: .constant("counted"), expression: .literal(.double(3)))],
                    result: .reference([.key("counted")])
                )
            ]
        )

        await #expect(throws: (any Error).self) {
            try await Executor()
                .run(try await builder.build([narrowing]))
        }
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
                        Statement(binding: .constant("counted"), expression: .literal(.int(3))
                        )
                    ],
                    result: .reference([.key("counted")])
                )
            ]
        )

        // When / Then. The body and the declaration beside it are one
        // document's text, so nothing has to run to find them disagreeing
        await #expect(throws: BuildError.self) {
            try await builder.build([sut])
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

        // When / Then. Two answers that disagree would join to `any`, and
        // `any` fits everything, so each is held on its own.
        let refusal = await #expect(throws: BuildError.self) {
            try await builder.build([sut])
        }

        #expect(refusal?.message.contains("declaration promises int") == true)
    }

    @Test("a declared type is settled on the way out, not only on the way in")
    func declaredTypeSettlesOnTheWayOut() async throws {
        // Given
        let sut = try Module(
            types: [
                "Task": .record([
                        "id": .string
                    ])
            ],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        returns: .array(.named("Task"))
                    ),
                    body: [
                        Statement(binding: .constant("made"), expression: .array([
                                    .record([
                                            "id": .literal(.string("a"))
                                        ])
                                ])
                        )
                    ],
                    result: .reference([.key("made")])
                )
            ]
        )

        // When
        let image = try await builder.build([sut])
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .array([.record(Record(name: "Task", ["id": .string("a")]))]))
    }

    @Test("an answer naming a type nobody declared is refused at link")
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
                        Statement(binding: .constant("done"), expression: .literal(.int(1))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            _ = try await builder.build([sut])
        }
    }
}

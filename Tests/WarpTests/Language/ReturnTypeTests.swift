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
    private let linker = Linker()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a declared answer is settled before the caller sees it")
    func answerIsSettled() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
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
        let image = try linker.link([sut], entry: entryName)
        let answer = try await Executor().run(image)

        // Then — settled to the declared representation, not merely waved past
        #expect(answer == .int(3))

        // And a fraction is not that representation, whatever it is worth: a
        // declaration is about the type, not about which values happen to fit.
        let narrowing = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [Statement(binding: .constant("counted"), expression: .literal(.double(3)))],
                    result: .reference([.key("counted")])
                )
            ]
        )

        await #expect(throws: (any Error).self) {
            try await Executor()
                .run(try linker.link([narrowing], entry: entryName))
        }
    }

    @Test("a body that answers something else fails")
    func wrongReturnFails() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("counted"), expression: .literal(.int(3))
                        )
                    ]
                )
            ]
        )

        // When / Then
        let image = try linker.link([sut], entry: entryName)

        await #expect(throws: ArgumentError.self) {
            try await Executor().run(image)
        }
    }

    @Test("a declared shape is settled on the way out, not only on the way in")
    func declaredShapeSettlesOnTheWayOut() async throws {
        // Given
        let sut = try Module(
            types: [
                "Task": .record([
                        "id": .string
                    ])
            ],
            procedures: [
                "entry": Procedure(
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
        let image = try linker.link([sut], entry: entryName)
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .array([.object(["id": .string("a")])]))
    }

    @Test("an answer naming a shape nobody declared is refused at link")
    func unknownReturnTypeIsALinkError() throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
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
        #expect(throws: LinkError.self) {
            _ = try linker.link([sut], entry: entryName)
        }
    }
}

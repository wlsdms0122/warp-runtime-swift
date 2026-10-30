//
//  IndexReferenceJudgementTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// The dot judged behind an index reference. The walk continues through `[i]`
// the way it does through `[0]`, so nothing after one escapes the build.
@Suite("The dot judged behind an index reference")
struct IndexReferenceJudgementTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant index inside an index reference folds, however deep")
    func nestedConstantIndexReferencesFold() async throws {
        // Given. `items[names[C]]`: the inner index reads a constant, and no
        // constant name survives into the image at any depth
        let sut = try Module(
            constants: ["C": .literal(.int(0))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string)),
                            Parameter(name: "names", type: .array(.int))
                        ],
                        returns: .string
                    ),
                    body: [
                        returning(.reference([
                            .name("items"),
                            .indexRef([.name("names"), .indexRef([.name("C")])])
                        ]))
                    ]
                )
            ]
        )

        // When / Then
        #expect(
            try await run(
                sut,
                arguments: [
                    "items": .array([.string("a"), .string("b")]),
                    "names": .array([.int(1)])
                ]
            ) == .string("b")
        )
    }

    @Test("an undeclared field behind an index reference refuses at the build")
    func anUndeclaredFieldBehindAnIndexReferenceRefuses() async throws {
        // Given. The element type is known whatever the index is, so the absent
        // field is the build's to refuse
        let sut = try Module(
            types: ["App.Item": .struct(["id": .string])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "items", type: .array(.named("App.Item")))
                        ]
                    ),
                    body: [
                        returning(.reference([
                            .name("items"),
                            .indexRef([.name("i")]),
                            .name("nope")
                        ]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("an index reference that provably is not a number refuses at the build")
    func anIndexReferenceReadingIsJudged() async throws {
        // Given. `name` is a string, and an index is an integer; the text
        // proves the defect, so the build refuses it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string)),
                            Parameter(name: "name", type: .string)
                        ]
                    ),
                    body: [returning(.reference([.name("items"), .indexRef([.name("name")])]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("expected Int")
        }
    }

    @Test("an index reference into what is not an array refuses like an index")
    func anIndexReferenceNeedsAnArray() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [returning(.reference([.name("text"), .indexRef([.name("i")])]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("brackets read a list by a position and a dictionary by a key")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

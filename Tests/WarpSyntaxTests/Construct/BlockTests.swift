//
//  BlockTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite
struct BlockTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("inner bindings stay inside; the block speaks with its declared output")
    func groupSpeaksWithDeclaredOutput() async throws {
        // Given
        let spec = try await loader.loadProcedure([
            "parameters": [["name": "who", "type": "string"]],
            "body": [
                [
                    "let": "greet",
                    "value": ["block": [
                        "body": [
                            [
                                "let": "base",
                                "value": [
                                    "format": "hello, ${who}",
                                    "with": ["who": ["ref": "who"]]
                                ]
                            ],
                            [
                                "let": "loud",
                                "value": ["format": "${text}!", "with": ["text": ["ref": "base"]]]
                            ]
                        ],
                        "result": ["ref": "loud"]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "greet"]]]
        ], importing: ["std.text.joined", "std.text.text"])

        // When
        let outputs = try await run(spec, arguments: ["who": .string("spec")])

        // Then. Inner bindings stay inside; the block speaks with one output
        #expect(outputs["result"] == .string("hello, spec!"))
    }

    @Test("a block with no declared result answers nothing")
    func groupWithoutAResultAnswersNothing() async throws {
        // Given. A block is a body, and a body answers what it says it answers.
        // Reading the last statement would make appending one change what the
        // block was worth, silently.
        let spec = try await loader.loadProcedure([
            "body": [
                [
                    "let": "block",
                    "value": ["block": [
                        "body": [["let": "first", "value": "a"], ["let": "second", "value": "b"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "block"]]]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .null)
    }

    @Test("a block body reading its own id is rejected at load")
    func groupSelfReadRejected() {
        // Given. Group binds nothing for its body; `${g.x}` inside it is a typo
        let fixture: Value = [
            "body": [["let": "g", "value": ["block": ["body": [["let": "inner", "value": ["ref": "g.x"]]]]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

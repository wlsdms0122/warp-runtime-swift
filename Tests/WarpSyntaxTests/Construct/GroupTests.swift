//
//  GroupTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite
struct GroupTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("inner bindings stay inside; the group speaks with its declared output")
    func groupSpeaksWithDeclaredOutput() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "parameters": ["who": "string"],
            "body": [
                [
                    "let": "greet",
                    "value": ["group": [
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
            "result": ["result": ["ref": "greet"]]
        ], importing: ["std.text.joined", "std.text.text"])

        // When
        let outputs = try await run(spec, arguments: ["who": .string("spec")])

        // Then — inner bindings stay inside; the group speaks with one output
        #expect(outputs["result"] == .string("hello, spec!"))
    }

    @Test("a group with no declared result answers nothing")
    func groupWithoutAResultAnswersNothing() async throws {
        // Given — a group is a body, and a body answers what it says it answers.
        // Reading the last statement would make appending one change what the
        // group was worth, silently.
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "let": "block",
                    "value": ["group": [
                        "body": [["let": "first", "value": "a"], ["let": "second", "value": "b"]]
                    ]
                ]]
            ],
            "result": ["result": ["ref": "block"]]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .null)
    }

    @Test("a group body reading its own id is rejected at load")
    func groupSelfReadRejected() {
        // Given — group binds nothing for its body; `${g.x}` inside it is a typo
        let fixture: Value = [
            "body": [["let": "g", "value": ["group": ["body": [["let": "inner", "value": ["ref": "g.x"]]]]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }
}

//
//  ClosureFormTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard
import WarpTestSupport

// A capability the language has and a document cannot write is a capability
// only Swift has. These are the two keys that close that gap.
@Suite("Writing a closure in a document")
struct ClosureFormTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("an author writes a construct that takes a body")
    func authorWrittenControlStructure() async throws {
        // Given. `twice` is a procedure, not a native procedure and not a language
        // case
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "body": [
                        [
                            "let": "ran",
                            "value": ["call": [
                                "procedure": "twice",
                                "arguments": [
                                    [
                                        "closure": [
                                            "returns": "String",
                                            "body": [["let": "said", "value": "hi"], ["value": ["return": ["ref": "said"]]]]
                                        ]
                                    ]
                                ]
                            ]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "ran"]]]]]]
                    ]
                ],
                "twice": [
                    "returns": "Any",
                    "parameters": [["name": "body", "type": "() -> String"]],
                    "body": [
                        ["let": "first", "value": ["call": ["procedure": ["ref": "body"]]]],
                        ["let": "second", "value": ["call": ["procedure": ["ref": "body"]]]],
                        ["value": ["return": ["dictionary": [["said", [["ref": "first"], ["ref": "second"]]]]]]]
                    ]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(
            outputs.dictionaryValue?["result"] == .dictionary(["said": .array([.string("hi"), .string("hi")])])
        )
    }

    @Test("a closure reads what surrounded it, not what called it")
    func closureCapturesLexically() async throws {
        // Given
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "body": [
                        ["let": "outer", "value": "written"],
                        [
                            "let": "made",
                            "value": [
                                "closure": [
                                    "returns": "String",
                                    "body": [["let": "seen", "value": ["ref": "outer"]], ["value": ["return": ["ref": "seen"]]]]
                                ]
                            ]
                        ],
                        [
                            "let": "said",
                            "value": ["call": ["procedure": "runner", "arguments": [["ref": "made"]]]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "said"]]]]]]
                    ]
                ],
                "runner": [
                    "returns": "Any",
                    "parameters": [["name": "body", "type": "() -> String"]],
                    "body": [
                        ["let": "outer", "value": "called"],
                        ["let": "ran", "value": ["call": ["procedure": ["ref": "body"]]]],
                        ["value": ["return": ["dictionary": [["said", ["ref": "ran"]]]]]]
                    ]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.dictionaryValue?["result"] == .dictionary(["said": .string("written")]))
    }

    @Test("a closure takes what it declares")
    func closureDeclaresParameters() async throws {
        // Given
        let sut = try loader.loadDocument([
            "imports": ["Standard.Text.joined", "Standard.Text.text"],
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "body": [
                        [
                            "let": "doubler",
                            "type": "(Int) -> String",
                            "value": [
                                "closure": [
                                    "returns": "String",
                                    "parameters": [["name": "n", "type": "Int"]],
                                    "body": [
                                        [
                                            "let": "out",
                                            "value": ["call": ["procedure": "Standard.Text.joined", "arguments": [["n=", ["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "n"]]]]], ""]]]
                                        ],
                                        ["value": ["return": ["ref": "out"]]]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "let": "said",
                            "value": ["call": ["procedure": ["ref": "doubler"], "arguments": [3]]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "said"]]]]]]
                    ]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.dictionaryValue?["result"] == .string("n=3"))
    }

    @Test("a closure body is checked where it is written")
    func closureBodyIsValidated() {
        // Given
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "made",
                            "value": [
                                "closure": ["body": [["let": "seen", "value": ["ref": "nowhere"]]]]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadDocument(fixture)
        }
    }

    @Test("a slot that declares what it wants refuses a closure that does not fit")
    func closureIsCheckedAgainstItsSlot() async throws {
        // Given. `twice` says the body it takes returns a string, and the
        // closure written at the call site says it returns an int
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "ran",
                            "value": ["call": [
                                "procedure": "twice",
                                "arguments": [
                                    [
                                        "closure": [
                                            "returns": "Int",
                                            "body": [["let": "said", "value": 1]]
                                        ]
                                    ]
                                ]
                            ]
                        ]]
                    ]
                ],
                "twice": [
                    "parameters": [["name": "body", "type": "() -> String"]],
                    "body": [["let": "first", "value": ["call": ["procedure": ["ref": "body"]]]]]
                ]
            ]
        ]

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try loader.loadDocument(fixture)] + Module.standard
            )
        }
    }

    @Test("a closure that fits its slot links")
    func fittingClosureLinks() async throws {
        // Given
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "ran",
                            "value": ["call": [
                                "procedure": "twice",
                                "arguments": [
                                    [
                                        "closure": [
                                            "returns": "String",
                                            "body": [["let": "said", "value": "hi"], ["value": ["return": ["ref": "said"]]]]
                                        ]
                                    ]
                                ]
                            ]
                        ]]
                    ]
                ],
                "twice": [
                    "parameters": [["name": "body", "type": "() -> String"]],
                    "body": [["let": "first", "value": ["call": ["procedure": ["ref": "body"]]]]]
                ]
            ]
        ]

        // When / Then
        _ = try await Builder().build(
            [try loader.loadDocument(fixture)] + Module.standard
        )
    }

    // MARK: - Public
    // MARK: - Private
}

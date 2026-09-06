//
//  ClosureNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard

// A capability the language has and the notation cannot spell is a capability
// only Swift has. These are the two words that close that gap.
@Suite("Writing a closure in a document")
struct ClosureNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("an author writes a construct that takes a body")
    func authorWrittenControlStructure() async throws {
        // Given — `twice` is a procedure, not a native word and not a language case
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "ran",
                            "value": ["call": [
                                "procedure": "twice",
                                "arguments": [
                                    "body": [
                                        "closure": [
                                            "body": [["let": "said", "value": "hi"]],
                                            "result": ["ref": "said"]
                                        ]
                                    ]
                                ]
                            ]
                        ]]
                    ],
                    "result": ["result": ["ref": "ran"]]
                ],
                "twice": [
                    "parameters": ["body": "procedure"],
                    "body": [
                        ["let": "first", "value": ["invoke": ["procedure": ["ref": "body"]]]],
                        ["let": "second", "value": ["invoke": ["procedure": ["ref": "body"]]]]
                    ],
                    "result": ["said": [["ref": "first"], ["ref": "second"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(
            outputs["result"] == .dictionary(["said": .array([.string("hi"), .string("hi")])])
        )
    }

    @Test("a closure reads what surrounded it, not what called it")
    func closureCapturesLexically() async throws {
        // Given
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "body": [
                        ["let": "outer", "value": "written"],
                        [
                            "let": "made",
                            "value": [
                                "closure": [
                                    "body": [["let": "seen", "value": ["ref": "outer"]]],
                                    "result": ["ref": "seen"]
                                ]
                            ]
                        ],
                        [
                            "let": "said",
                            "value": ["call": ["procedure": "runner", "arguments": ["body": ["ref": "made"]]]
                        ]]
                    ],
                    "result": ["result": ["ref": "said"]]
                ],
                "runner": [
                    "parameters": ["body": "procedure"],
                    "body": [
                        ["let": "outer", "value": "called"],
                        ["let": "ran", "value": ["invoke": ["procedure": ["ref": "body"]]]]
                    ],
                    "result": ["said": ["ref": "ran"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .dictionary(["said": .string("written")]))
    }

    @Test("a closure takes what it declares")
    func closureDeclaresParameters() async throws {
        // Given
        let sut = try loader.loadDocument([
            "imports": ["std.text.joined", "std.text.text"],
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "doubler",
                            "value": [
                                "closure": [
                                    "parameters": ["n": "int"],
                                    "body": [
                                        [
                                            "let": "out",
                                            "value": [
                                                "format": "n=${n}",
                                                "with": ["n": ["ref": "n"]]
                                            ]
                                        ]
                                    ],
                                    "result": ["ref": "out"]
                                ]
                            ]
                        ],
                        [
                            "let": "said",
                            "value": ["invoke": ["procedure": ["ref": "doubler"], "arguments": ["n": 3]]
                        ]]
                    ],
                    "result": ["result": ["ref": "said"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .string("n=3"))
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
        #expect(throws: (any Error).self) {
            try loader.loadDocument(fixture)
        }
    }

    @Test("a slot that declares what it wants refuses a closure that does not fit")
    func closureIsCheckedAgainstItsSlot() throws {
        // Given — `twice` says the body it takes answers a string, and the
        // closure written at the call site says it answers an int
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "ran",
                            "value": ["call": [
                                "procedure": "twice",
                                "arguments": [
                                    "body": [
                                        "closure": [
                                            "returns": "int",
                                            "body": [["let": "said", "value": 1]]
                                        ]
                                    ]
                                ]
                            ]
                        ]]
                    ]
                ],
                "twice": [
                    "parameters": ["body": ["type": ["procedure": ["returns": "string"]]]],
                    "body": [["let": "first", "value": ["invoke": ["procedure": ["ref": "body"]]]]]
                ]
            ]
        ]

        // When / Then
        #expect(throws: LinkError.self) {
            try Linker().link(
                [try loader.loadDocument(fixture)] + Module.standard,
                entry: entryName
            )
        }
    }

    @Test("a closure that fits its slot links")
    func fittingClosureLinks() throws {
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
                                    "body": [
                                        "closure": [
                                            "returns": "string",
                                            "body": [["let": "said", "value": "hi"]]
                                        ]
                                    ]
                                ]
                            ]
                        ]]
                    ]
                ],
                "twice": [
                    "parameters": ["body": ["type": ["procedure": ["returns": "string"]]]],
                    "body": [["let": "first", "value": ["invoke": ["procedure": ["ref": "body"]]]]]
                ]
            ]
        ]

        // When / Then
        _ = try Linker().link(
            [try loader.loadDocument(fixture)] + Module.standard,
            entry: entryName
        )
    }
}

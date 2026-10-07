//
//  CanonicalTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// The document has two layers, and this suite is about the lower one: the types
// that stand one to one with the language, written without any spelling that
// stands in for a procedure.
//
// It matters because the lower layer is what travels. A program that leaves the
// machine it was written on arrives somewhere that has to read it, and every
// spelling is a rule that somewhere else has to implement the same way. The
// fewer of them the arriving side must understand, the smaller the promise.
@Suite("A document can be written without its spellings")
struct CanonicalTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a conditional reads a condition written as a plain call")
    func branchReadsAPlainCondition() async throws {
        // Given. `{ of: x, is: 1 }` is one way to arrive at a condition. The
        // slot asks for an expression, and this is another.
        let sut = try loader.loadProcedure([
            "parameters": [["name": "count", "type": "int"]],
            "body": [
                ["var": "pick"],
                [
                    "value": ["conditional": [
                        "when": [
                            "call": [
                                "procedure": "Standard.Logic.equal",
                                "arguments": [["ref": "count"], 1]
                            ]
                        ],
                        "then": [["set": "pick", "value": "one"]],
                        "else": [["set": "pick", "value": "more"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "pick"]]]
        ], importing: ["Standard.Logic.equal"])

        // When
        let one = try await run(sut, arguments: ["count": .int(1)])
        let more = try await run(sut, arguments: ["count": .int(2)])

        // Then
        #expect(one["result"] == .string("one"))
        #expect(more["result"] == .string("more"))
    }

    @Test("a loop reads a condition written as a plain call")
    func loopReadsAPlainCondition() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "seen", "value": 0],
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": [
                            "call": [
                                "procedure": "Standard.Logic.notEqual",
                                "arguments": [["ref": "seen"], 3]
                            ]
                        ],
                        "body": [
                            [
                                "set": "seen",
                                "value": ["call": [
                                    "procedure": "Standard.Math.plus",
                                    "arguments": [["ref": "seen"], 1]
                                ]
                            ]]
                        ]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "seen"]]]
        ], importing: ["Standard.Logic.notEqual", "Standard.Math.plus"])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .int(3))
    }

    @Test("a spelling and the call it stands for are the same program")
    func aSpellingMeansTheCallItStandsFor() async throws {
        // Given. The same question asked both ways. This is what makes the
        // spellings a layer rather than a part of the language: what they lower
        // to is writable, so nothing is only reachable by spelling it.
        func picking(on condition: Value) throws -> Module {
            try loader.loadProcedure([
                "parameters": [["name": "word", "type": "string"]],
                "body": [
                    ["var": "pick"],
                    [
                        "value": ["conditional": [
                            "when": condition,
                            "then": [["set": "pick", "value": "matched"]],
                            "else": [["set": "pick", "value": "missed"]]
                        ]
                    ]]
                ],
                "result": ["record": ["result": ["ref": "pick"]]]
            ], importing: ["Standard.Logic.equal"])
        }

        let spelled = try picking(on: ["of": ["ref": "word"], "equal": "hey"])
        let plainly = try picking(on: [
            "call": [
                "procedure": "Standard.Logic.equal",
                "arguments": [["ref": "word"], "hey"]
            ]
        ])

        // When
        let hit = (
            try await run(spelled, arguments: ["word": .string("hey")]),
            try await run(plainly, arguments: ["word": .string("hey")])
        )
        let miss = (
            try await run(spelled, arguments: ["word": .string("ho")]),
            try await run(plainly, arguments: ["word": .string("ho")])
        )

        // Then
        #expect(hit.0 == hit.1)
        #expect(miss.0 == miss.1)
        #expect(hit.0["result"] == .string("matched"))
        #expect(miss.0["result"] == .string("missed"))
    }

    @Test("a condition that is simply a name is read as one")
    func aBareReferenceIsACondition() async throws {
        // Given. Nothing about a condition says it must be a comparison. A
        // boolean already is one, and demanding it be spelled as `{ of: x, is:
        // true }` would be the notation making up a requirement.
        let sut = try loader.loadProcedure([
            "parameters": [["name": "ready", "type": "bool"]],
            "body": [
                ["var": "pick"],
                [
                    "value": ["conditional": [
                        "when": ["ref": "ready"],
                        "then": [["set": "pick", "value": "go"]],
                        "else": [["set": "pick", "value": "wait"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "pick"]]]
        ])

        // When
        let outputs = try await run(sut, arguments: ["ready": .bool(true)])

        // Then
        #expect(outputs["result"] == .string("go"))
    }

    @Test("a program that does not hold together is still one document")
    func anUnsoundDocumentIsStillADocument() throws {
        // Given. A name nothing declares. What a text *is* and whether its
        // program is any good are two questions, and the first is the one a
        // caller asks when it wants the file a refusal came from. Answering it
        // only for the texts that had nothing wrong with them would take the
        // answer away exactly where it is wanted.
        let unsound: Value = [
            "imports": [],
            "procedures": ["entry": ["result": ["ref": "missing"]]]
        ]

        // When
        let written = try loader.canonical(unsound, from: .testing)

        // Then, which document this is comes off the canonical writing, so the
        // same text twice is the same document
        #expect(written == (try loader.canonical(unsound, from: .testing)))

        // And the program is still refused when something asks whether it holds
        #expect(throws: ValidationError.self) {
            try loader.load(written, identity: nil)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

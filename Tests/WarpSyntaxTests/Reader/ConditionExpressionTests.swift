//
//  ConditionExpressionTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// A condition is an expression like any other: a call that answers a boolean,
// or a name that holds one.
@Suite("A condition written as an expression")
struct ConditionExpressionTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a conditional reads a condition written as a plain call")
    func branchReadsAPlainCondition() async throws {
        // Given. `{ of: x, is: 1 }` is one way to arrive at a condition. The
        // slot asks for an expression, and this is another.
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "parameters": [["name": "count", "type": "Int"]],
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
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "pick"]]]]]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let one = try await run(sut, arguments: ["count": .int(1)])
        let more = try await run(sut, arguments: ["count": .int(2)])

        // Then
        #expect(one.dictionaryValue?["result"] == .string("one"))
        #expect(more.dictionaryValue?["result"] == .string("more"))
    }

    @Test("a loop reads a condition written as a plain call")
    func loopReadsAPlainCondition() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "returns": "Any",
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
                                    "procedure": "Standard.Numeric.plus",
                                    "arguments": [["ref": "seen"], 1]
                                ]
                            ]]
                        ]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "seen"]]]]]]
            ]
        ], importing: ["Standard.Logic.notEqual", "Standard.Numeric.plus"])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.dictionaryValue?["result"] == .int(3))
    }

    @Test("a condition that is simply a name is read as one")
    func aBareReferenceIsACondition() async throws {
        // Given. Nothing about a condition says it must be a comparison. A
        // boolean already is one.
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "parameters": [["name": "ready", "type": "Bool"]],
            "body": [
                ["var": "pick"],
                [
                    "value": ["conditional": [
                        "when": ["ref": "ready"],
                        "then": [["set": "pick", "value": "go"]],
                        "else": [["set": "pick", "value": "wait"]]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "pick"]]]]]]
            ]
        ])

        // When
        let outputs = try await run(sut, arguments: ["ready": .bool(true)])

        // Then
        #expect(outputs.dictionaryValue?["result"] == .string("go"))
    }

    // MARK: - Public
    // MARK: - Private
}

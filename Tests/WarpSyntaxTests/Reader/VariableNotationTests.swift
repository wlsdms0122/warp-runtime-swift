//
//  VariableNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// How a document spells a binding. `id:`, `var:`, `set:`. What a binding
// *means* is the language's, and `WarpTests` asks it there.
@Suite("How a document spells a binding")
struct VariableNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a write inside a nested body outlives it")
    func assignmentOutlivesItsBlock() async throws {
        // Given. The one thing a binding cannot do: a conditional that ran changes
        // what an enclosing name means afterwards
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "parameters": [["name": "kind", "type": "String"]],
            "body": [
                ["var": "verdict", "value": "untouched"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "verdict", "value": "touched"]]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "verdict"]]]]]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("a")])

        // Then
        #expect(outputs.map?["result"] == .string("touched"))
    }

    @Test("a conditional that did not run changes nothing")
    func untakenBranchLeavesVariableAlone() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "parameters": [["name": "kind", "type": "String"]],
            "body": [
                ["var": "verdict", "value": "untouched"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "verdict", "value": "touched"]]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "verdict"]]]]]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("b")])

        // Then
        #expect(outputs.map?["result"] == .string("untouched"))
    }

    @Test("a variable declared inside a nested body does not escape it")
    func innerVariableDoesNotEscape() throws {
        // Given. The box is shared, but which names exist is not: `var` inside
        // a conditional introduces a name that dies with the conditional
        let fixture: Value = [
            "body": [
                ["let": "seed", "value": 1],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "seed"], "notEqual": .null],
                        "then": [["var": "inner", "value": 1]]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "inner"]]]]]]
            ]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a var inside a nested body shadows the outer one instead of writing it")
    func innerVariableShadowsOuter() async throws {
        // Given. `var` always introduces, so the inner name is a different name
        // with a box of its own. Writing the outer one is `set`.
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "body": [
                ["var": "verdict", "value": "outer"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "verdict"], "notEqual": .null],
                        "then": [["var": "verdict", "value": "inner"]]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "verdict"]]]]]]
            ]
        ], importing: ["Standard.Logic.notEqual"])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.map?["result"] == .string("outer"))
    }

    @Test("writing a fixed name is rejected at load")
    func assigningConstantRejected() throws {
        // Given. `id` means the name is fixed, and the refusal says which of
        // the two mistakes this is
        let fixture: Value = [
            "body": [["let": "verdict", "value": "first"], ["set": "verdict", "value": "second"], ["value": ["return": ["dictionary": [["result", ["ref": "verdict"]]]]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("writing a name nothing declared is rejected at load")
    func assigningUndeclaredRejected() throws {
        // Given
        let fixture: Value = [
            "body": [["set": "verdict", "value": "second"], ["value": ["return": ["dictionary": [["result", ["ref": "verdict"]]]]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a closure may write a variable it captured")
    func closureWritesWhatItCaptured() throws {
        // Given. A variable's box is one thing under one name everywhere the
        // name is visible, and the closure's body is one of those places
        let fixture: Value = [
            "body": [
                ["var": "tally", "value": 0],
                [
                    "let": "later",
                    "value": [
                        "closure": [
                            "body": [["set": "tally", "value": 1], ["value": ["return": ["ref": "tally"]]]]
                        ]
                    ]
                ],
                ["value": ["return": ["dictionary": [["result", ["ref": "tally"]]]]]]
            ]
        ]

        // When / Then
        #expect(throws: Never.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a closure may declare and write its own variable")
    func closureOwnsItsVariables() async throws {
        // Given. What is forbidden is reaching outward, not variables
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "failing": ["concurrent_failed"],
            "body": [
                [
                    "let": "both",
                    "value": ["call": [
                        "procedure": "Standard.Concurrent.allKeyed",
                        "arguments": [
                            ["dictionary": [["left", [
                                    "closure": [
                                        "returns": "Int",
                                        "isolated": true,
                                        "body": [
                                            ["var": "tally", "value": 0],
                                            ["set": "tally", "value": 1],
                                            ["value": ["return": ["ref": "tally"]]]
                                        ]
                                    ]
                                ]], ["right", ["closure": ["returns": "Int", "isolated": true, "body": [["value": ["return": 2]]]]]]]]
                        ]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "both[\"left\"]"]]]]]]
            ]
        ], importing: ["Standard.Concurrent.allKeyed"])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.map?["result"] == .int(1))
    }

    @Test("a step naming itself twice is rejected at load")
    func doubleNameKeyRejected() throws {
        // Given. `id`/`var`/`set` are one slot spelled three ways, not three
        // keys that may combine
        let fixture: Value = ["body": [["let": "verdict", "var": "verdict", "value": "x"]]]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

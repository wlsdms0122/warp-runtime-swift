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
@Suite
struct VariableNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a write inside a block outlives the block")
    func assignmentOutlivesItsBlock() async throws {
        // Given. The one thing a binding cannot do: a conditional that ran changes
        // what an enclosing name means afterwards
        let sut = try loader.loadProcedure([
            "parameters": [["name": "kind", "type": "string"]],
            "body": [
                ["var": "verdict", "value": "untouched"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "verdict", "value": "touched"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "verdict"]]]
        ], importing: ["std.logic.equal"])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("a")])

        // Then
        #expect(outputs["result"] == .string("touched"))
    }

    @Test("a conditional that did not run changes nothing")
    func untakenBranchLeavesVariableAlone() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "parameters": [["name": "kind", "type": "string"]],
            "body": [
                ["var": "verdict", "value": "untouched"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "verdict", "value": "touched"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "verdict"]]]
        ], importing: ["std.logic.equal"])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("b")])

        // Then
        #expect(outputs["result"] == .string("untouched"))
    }

    @Test("a variable declared inside a block does not escape it")
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
                ]]
            ],
            "result": ["record": ["result": ["ref": "inner"]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a var inside a block shadows the outer one instead of writing it")
    func innerVariableShadowsOuter() async throws {
        // Given. `var` always introduces, so the inner name is a different name
        // with a box of its own. Writing the outer one is `set`.
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "verdict", "value": "outer"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "verdict"], "notEqual": .null],
                        "then": [["var": "verdict", "value": "inner"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "verdict"]]]
        ], importing: ["std.logic.notEqual"])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .string("outer"))
    }

    @Test("writing a fixed name is rejected at load")
    func assigningConstantRejected() throws {
        // Given. `id` means the name is fixed, and the refusal says which of
        // the two mistakes this is
        let fixture: Value = [
            "body": [["let": "verdict", "value": "first"], ["set": "verdict", "value": "second"]],
            "result": ["record": ["result": ["ref": "verdict"]]]
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
            "body": [["set": "verdict", "value": "second"]],
            "result": ["record": ["result": ["ref": "verdict"]]]
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
                            "body": [["set": "tally", "value": 1]],
                            "result": ["ref": "tally"]
                        ]
                    ]
                ]
            ],
            "result": ["record": ["result": ["ref": "tally"]]]
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
            "body": [
                [
                    "let": "both",
                    "value": ["call": [
                        "procedure": "std.concurrent.all",
                        "arguments": [
                            ["record": [
                                "left": [
                                    "closure": [
                                        "body": [
                                            ["var": "tally", "value": 0],
                                            ["set": "tally", "value": 1]
                                        ],
                                        "result": ["ref": "tally"]
                                    ]
                                ],
                                "right": ["closure": ["result": 2]]
                            ]]
                        ]
                    ]
                ]],
                [
                    "let": "read",
                    "value": ["as": ["of": ["ref": "both"], "type": ["record": ["left": "int"]]]]
                ]
            ],
            "result": ["record": ["result": ["ref": "read.left"]]]
        ], importing: ["std.concurrent.all"])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .int(1))
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

//
//  ConditionalTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

@Suite("A conditional runs the arm its condition picks")
struct ConditionalTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("conditional selects the then/else arm by its condition")
    func branchSelectsArm() async throws {
        // Given. An arm is statements alone: what it keeps it writes to an
        // outer variable, and the conditional itself has no value
        let spec = try loader.loadProcedure([
            "returns": "Any",
            "parameters": [["name": "kind", "type": "String"]],
            "body": [
                ["var": "pick"],
                [
                    "value": ["conditional": [
                        "when": ["call": ["procedure": "Standard.Logic.equal", "arguments": [["ref": "kind"], "a"]]],
                        "then": [["set": "pick", "value": "took-then"]],
                        "else": [["set": "pick", "value": "took-else"]]
                    ]
                ]],
                ["value": ["return": ["dictionary": [["result", ["ref": "pick"]]]]]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let thenOutputs = try await run(spec, arguments: ["kind": .string("a")])
        let elseOutputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then
        #expect(thenOutputs.dictionaryValue?["result"] == .string("took-then"))
        #expect(elseOutputs.dictionaryValue?["result"] == .string("took-else"))
    }

    @Test("a name on a conditional is refused at the load")
    func aNameOnABranchIsRefused() {
        // When / Then. A conditional has no value, so its name could never
        // bind
        #expect {
            try loader.loadProcedure([
                "body": [
                    [
                        "let": "pick",
                        "value": ["conditional": [
                            "when": true,
                            "then": [["let": "kept", "value": "yes"]]
                        ]
                    ]]
                ]
            ])
        } throws: { error in
            "\(error)".contains("takes no name")
        }
    }

    @Test("a bare var declares a name holding null")
    func aBareVarDeclaresNull() async throws {
        // Given. `var` may stand alone: it introduces a name with nothing in it
        // yet, for the writes a conditional's arms make
        let spec = try loader.loadProcedure([
            "returns": "Any",
            "body": [
                ["var": "kept"],
                ["value": ["return": ["dictionary": [["result", ["ref": "kept"]]]]]]
            ]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs.dictionaryValue?["result"] == .null)
    }

    // MARK: - Public
    // MARK: - Private
}

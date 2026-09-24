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

@Suite
struct ConditionalTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("conditional selects the then/else arm by its condition")
    func branchSelectsArm() async throws {
        // Given. An arm is statements alone: what it keeps it writes to an
        // outer variable, and the conditional itself answers nothing
        let spec = try await loader.loadProcedure([
            "parameters": [["name": "kind", "type": "string"]],
            "body": [
                ["var": "pick"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "pick", "value": "took-then"]],
                        "else": [["set": "pick", "value": "took-else"]]
                    ]
                ]]
            ],
            "result": ["result": ["ref": "pick"]]
        ], importing: ["std.logic.equal"])

        // When
        let thenOutputs = try await run(spec, arguments: ["kind": .string("a")])
        let elseOutputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then
        #expect(thenOutputs["result"] == .string("took-then"))
        #expect(elseOutputs["result"] == .string("took-else"))
    }

    @Test("a name on a conditional is refused at reading")
    func aNameOnABranchIsRefused() {
        // Given. A conditional answers nothing, so its name could never bind
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
        let spec = try await loader.loadProcedure([
            "body": [
                ["var": "kept"]
            ],
            "result": ["result": ["ref": "kept"]]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .null)
    }
}

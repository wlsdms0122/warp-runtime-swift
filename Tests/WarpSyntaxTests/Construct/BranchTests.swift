//
//  BranchTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite
struct BranchTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("branch selects the then/else arm by its condition")
    func branchSelectsArm() async throws {
        // Given — an arm is statements alone: what it keeps it writes to an
        // outer variable, and the branch itself answers nothing
        let spec = try loader.loadProcedure([
            "parameters": ["kind": "string"],
            "body": [
                ["var": "pick"],
                [
                    "branch": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "pick", "value": "took-then"]],
                        "else": [["set": "pick", "value": "took-else"]]
                    ]
                ]
            ],
            "result": ["result": ["ref": "pick"]]
        ], importing: ["equal"])

        // When
        let thenOutputs = try await run(spec, arguments: ["kind": .string("a")])
        let elseOutputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then
        #expect(thenOutputs["result"] == .string("took-then"))
        #expect(elseOutputs["result"] == .string("took-else"))
    }

    @Test("a name on a branch is refused at reading")
    func aNameOnABranchIsRefused() {
        // Given — a branch answers nothing, so its name could never bind
        #expect {
            try loader.loadProcedure([
                "body": [
                    [
                        "id": "pick",
                        "branch": [
                            "when": true,
                            "then": [["id": "kept", "value": "yes"]]
                        ]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("takes no name")
        }
    }

    @Test("a bare var declares a name holding null")
    func aBareVarDeclaresNull() async throws {
        // Given — `var` may stand alone: it introduces a name with nothing in
        // it yet, for the writes a branch's arms make
        let spec = try loader.loadProcedure([
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

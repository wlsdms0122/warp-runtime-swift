//
//  SpellingTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// A construct's procedure belongs to the table, not to the type that reads it. The
// language's constructs are anonymous, so nothing downstream of the registry
// can tell which procedure arrived, and these are the facts that follow.
@Suite("A procedure belongs to the registry")
struct SpellingTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a form can be registered under another procedure")
    func formIsRegisteredUnderAnotherKey() async throws {
        // Given. `unless` is `conditional` spelled differently, and the IR it builds
        // cannot say which of the two was written
        let loader = Loader(
            registry: try ConstructRegistry.standard.registering(
                ConditionalForm.self,
                as: "unless"
            )
        )
        let sut = try await loader.loadProcedure([
            "parameters": [["name": "kind", "type": "string"]],
            "body": [
                ["var": "pick"],
                [
                    "value": ["unless": [
                        "when": ["of": ["ref": "kind"], "equal": "a"],
                        "then": [["set": "pick", "value": "took-then"]],
                        "else": [["set": "pick", "value": "took-else"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "pick"]]]
        ], importing: ["std.logic.equal"])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("a")])

        // Then
        #expect(outputs["result"] == .string("took-then"))
    }

    @Test("registering a form twice is an alias, so both procedures work")
    func aliasKeepsBothKeys() throws {
        // Given / When
        let sut = try ConstructRegistry.standard.registering(ConditionalForm.self, as: "unless")

        // Then
        #expect(sut.form(for: "conditional") != nil)
        #expect(sut.form(for: "unless") != nil)
    }

    @Test("a procedure can be given up, and a built-in respelled by giving it up first")
    func removingFreesTheKey() throws {
        // Given. A notation that wants `call` for something of its own takes
        // it by dropping ours, which is why a rename here is not a rename of
        // the language
        let sut = try ConstructRegistry.standard
            .removing("call")
            .registering(CallForm.self, as: "invoke")

        // Then
        #expect(sut.form(for: "call") == nil)
        #expect(sut.form(for: "invoke") != nil)
    }

    @Test("a claimed procedure is never silently replaced, however it was claimed")
    func claimedKeyRejected() throws {
        // Given
        let sut = try ConstructRegistry.standard.registering(ConditionalForm.self, as: "unless")

        // When / Then. The guard is on the procedure, not on the form
        #expect(throws: ValidationError.self) {
            try sut.registering(LoopForm.self, as: "unless")
        }
    }

    @Test("a construct is not registered under an expression's tag", arguments: ["record", "ref", "as", "closure"])
    func aTagIsNoConstructKey(tag: String) {
        // Given / When / Then. A tag is read as its expression under a
        // statement's `value` too, so a construct under one would take a
        // record or a reference for itself
        #expect(throws: ValidationError.self) {
            try ConstructRegistry.standard.removing("conditional").registering(ConditionalForm.self, as: Name(tag))
        }
    }

    @Test("a procedure the registry does not hold is not a construct")
    func unregisteredKeyRefused() {
        // Given. `conditional` given up is `conditional` unspellable
        let loader = Loader(registry: ConstructRegistry.standard.removing("conditional"))

        // When / Then
        #expect(throws: (any Error).self) {
            try loader.loadProcedure([
                "parameters": [["name": "kind", "type": "string"]],
                "body": [
                    [
                        "let": "pick",
                        "value": ["conditional": [
                            "when": ["of": ["ref": "kind"], "equal": "a"],
                            "then": [
                                "body": [["let": "chosen", "value": "took-then"]],
                                "result": ["value": ["ref": "chosen"]]
                            ]
                        ]
                    ]]
                ]
            ])
        }
    }
}

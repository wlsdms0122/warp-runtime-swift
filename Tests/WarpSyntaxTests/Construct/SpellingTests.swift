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
import WarpTestSupport

// A construct's key belongs to the table, not to the type that reads it. The
// language's constructs are anonymous, so nothing downstream of the registry
// can tell which key arrived, and these are the facts that follow.
@Suite("A key belongs to the registry")
struct SpellingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the language's own table registers as a composed one does")
    func standardTableRegisters() throws {
        // Given. `standard` stands without the registration's judgement
        let forms = ConstructRegistry.standard.keys.compactMap(ConstructRegistry.standard.form(for:))

        // When
        let sut = try ConstructRegistry(forms: forms)

        // Then
        #expect(sut.keys == ConstructRegistry.standard.keys)
    }

    @Test("a form can be registered under another key")
    func formIsRegisteredUnderAnotherKey() async throws {
        // Given. `unless` is `conditional` spelled differently, and the IR it builds
        // cannot say which of the two was written
        let loader = Loader(
            registry: try ConstructRegistry.standard.registering(
                ConditionalForm.self,
                as: "unless"
            )
        )
        let sut = try loader.loadProcedure([
            "parameters": [["name": "kind", "type": "String"]],
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
            "result": ["dictionary": [["result", ["ref": "pick"]]]]
        ], importing: ["Standard.Logic.equal"])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("a")])

        // Then
        #expect(outputs.map?["result"] == .string("took-then"))
    }

    @Test("registering a form twice is an alias, so both keys work")
    func aliasKeepsBothKeys() throws {
        // Given / When
        let sut = try ConstructRegistry.standard.registering(ConditionalForm.self, as: "unless")

        // Then
        #expect(sut.form(for: "conditional") != nil)
        #expect(sut.form(for: "unless") != nil)
    }

    @Test("a key can be given up, and a built-in respelled by giving it up first")
    func removingFreesTheKey() throws {
        // Given / When. A notation that wants `loop` for something of its own
        // takes it by dropping ours, which is why a rename here is not a rename
        // of the language
        let sut = try ConstructRegistry.standard
            .removing("loop")
            .registering(LoopForm.self, as: "repeat")

        // Then
        #expect(sut.form(for: "loop") == nil)
        #expect(sut.form(for: "repeat") != nil)
    }

    @Test("a claimed key is never silently replaced, however it was claimed")
    func claimedKeyRejected() throws {
        // Given
        let sut = try ConstructRegistry.standard.registering(ConditionalForm.self, as: "unless")

        // When / Then. The guard is on the key, not on the form
        #expect(throws: ConstructRegistryError.self) {
            try sut.registering(LoopForm.self, as: "unless")
        }
    }

    @Test("a construct is not registered under an expression's tag", arguments: ["struct", "ref", "as", "closure"])
    func aTagIsNoConstructKey(tag: String) {
        // Given / When / Then. A tag is read as its expression under a
        // statement's `value` too, so a construct under one would take a
        // struct or a reference for itself
        #expect(throws: ConstructRegistryError.self) {
            try ConstructRegistry.standard.removing("conditional").registering(ConditionalForm.self, as: Name(tag))
        }
    }

    @Test("a key the registry does not hold is not a construct")
    func unregisteredKeyRefused() {
        // Given. `conditional` given up is `conditional` unspellable
        let loader = Loader(registry: ConstructRegistry.standard.removing("conditional"))

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "parameters": [["name": "kind", "type": "String"]],
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

    // MARK: - Public
    // MARK: - Private
}

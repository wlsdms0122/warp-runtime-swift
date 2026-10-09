//
//  ModuleDeclarationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// A module declares more than procedures, and what it declares is its own. A
// corpus whose names all went into one shared space could not grow without them
// colliding, and a value used in three places had to be written three times.
@Suite("What a module declares")
struct ModuleDeclarationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a spelling names the declaration written under it, in its own document too")
    func ownDeclarationIsSpelledQualified() async throws {
        // Given. `first` calls its own `helper` as `First.helper`, and `second`
        // declares a `helper` of its own, which is `Second.helper`
        let first = try loader.loadDocument([
            "procedures": [
                "First.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "First.helper"]]]],
                    "result": ["record": ["result": ["ref": "said"]]]
                ],
                "First.helper": [
                    "body": [["let": "done", "value": "from first"]],
                    "result": ["record": ["said": ["ref": "done"]]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "procedures": [
                "Second.helper": [
                    "body": [["let": "done", "value": "from second"]],
                    "result": ["record": ["said": ["ref": "done"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "First.entry")

        // Then
        #expect(outputs["result"] == .dictionary(["said": .string("from first")]))
    }

    @Test("a bare name for another module's procedure is refused at the build")
    func aBareNameForAnotherModulesProcedureIsRefused() async throws {
        // Given
        let caller = try loader.loadDocument([
            "imports": ["greet"],
            "procedures": [
                "Caller.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "greet"]]]],
                    "result": ["record": ["result": ["ref": "said"]]]
                ]
            ]
        ])
        let library = try loader.loadDocument([
            "procedures": [
                "Greeting.greet": [
                    "body": [["let": "done", "value": "hello"]],
                    "result": ["record": ["said": ["ref": "done"]]]
                ]
            ]
        ])

        // When / Then
        await #expect {
            try await Builder().build([caller, library])
        } throws: { error in
            "\(error)".contains("sends 'greet', which no module in this link declares")
        }
    }

    @Test("a spelling reaches the declaration under it, whichever document wrote it")
    func qualifiedNameReachesAcross() async throws {
        // Given. `first` has a `helper` of its own and asks for the other one
        let first = try loader.loadDocument([
            "imports": ["Second.helper"],
            "procedures": [
                "First.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "Second.helper"]]]],
                    "result": ["record": ["result": ["ref": "said"]]]
                ],
                "First.helper": [
                    "body": [["let": "done", "value": "from first"]],
                    "result": ["record": ["said": ["ref": "done"]]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "procedures": [
                "Second.helper": [
                    "body": [["let": "done", "value": "from second"]],
                    "result": ["record": ["said": ["ref": "done"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "First.entry")

        // Then
        #expect(outputs["result"] == .dictionary(["said": .string("from second")]))
    }

    @Test("a constant is a name bound to a value, settled before any run")
    func constantsFoldAtTheBuild() async throws {
        // Given
        let sut = try loader.loadDocument([
            "const": ["greeting": "hello", "limit": 3],
            "procedures": [
                "entry": [
                    "body": [["let": "said", "value": ["ref": "greeting"]]],
                    "result": ["record": ["result": ["ref": "said"], "cap": ["ref": "limit"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .string("hello"))
        #expect(outputs["cap"] == .int(3))
    }

    @Test("a constant may name another declared beside it, but not one that names it back")
    func constantsMayComposeButNotCycle() async throws {
        // Given
        let composed = try loader.loadDocument([
            "imports": ["Standard.Text.joined", "Standard.Text.text"],
            "const": [
                "host": "example.com",
                "url": ["format": "https://${host}/api", "with": ["host": ["ref": "host"]]]
            ],
            "procedures": [
                "entry": [
                    "body": [["let": "seen", "value": ["ref": "url"]]],
                    "result": ["record": ["result": ["ref": "seen"]]]
                ]
            ]
        ])
        let cyclic = try loader.loadDocument([
            "const": ["a": ["ref": "b"], "b": ["ref": "a"]],
            "procedures": ["entry": ["body": [["let": "seen", "value": ["ref": "a"]]]]]
        ])

        // When / Then
        let outputs = try await run(composed)

        #expect(outputs["result"] == .string("https://example.com/api"))

        await #expect(throws: BuildError.self) {
            try await Builder().build([cyclic])
        }
    }

    @Test("a statement may not reintroduce a name the module bound")
    func constantsCannotBeShadowed() {
        // Given. Compiling folds a reference to a constant into its value, so a
        // second reading of the same spelling could never be true
        let fixture: Value = [
            "const": ["limit": 3],
            "procedures": ["entry": ["body": [["let": "limit", "value": 4]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try validated(try loader.loadDocument(fixture))
        }
    }

    @Test("a document declares a contract, and a procedure reaches it through the contract's name")
    func aDocumentDeclaresAContract() async throws {
        // Given. Two types that describe themselves, and one procedure that knows
        // neither
        let sut = try loader.loadDocument([
            "types": [
                "Bank.Account": ["record": ["balance": "Int"]],
                "Bank.Card": ["record": ["last": "String"]]
            ],
            "contracts": [
                "App.Describable": [
                    "describe": ["parameters": [["name": "of", "type": "Self"]], "returns": "String"]
                ]
            ],
            "satisfies": [
                "Bank.Account": ["App.Describable"],
                "Bank.Card": ["App.Describable"]
            ],
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "card",
                            "value": ["as": ["of": ["record": ["last": "42"]], "type": "Bank.Card"]]
                        ]
                    ],
                    "result": ["record": ["result": ["call": ["procedure": "App.tell", "arguments": [["ref": "card"]]]]]]
                ],
                "App.tell": [
                    "parameters": [["name": "it", "type": "some T"]],
                    "bounds": ["T": "App.Describable"],
                    "returns": "String",
                    "result": ["call": ["procedure": "App.Describable.describe", "arguments": [["ref": "it"]]]]
                ],
                "Bank.Account.describe": [
                    "parameters": [["name": "of", "type": "Bank.Account"]],
                    "returns": "String",
                    "result": "an account"
                ],
                "Bank.Card.describe": [
                    "parameters": [["name": "of", "type": "Bank.Card"]],
                    "returns": "String",
                    "result": "a card"
                ]
            ]
        ])

        // When / Then
        let outputs = try await run(sut, entry: "entry")

        #expect(outputs["result"] == .string("a card"))
    }

    // MARK: - Public
    // MARK: - Private
    private func validated(_ module: Module) throws -> Module {
        try Validator().validate(module)

        return module
    }
}

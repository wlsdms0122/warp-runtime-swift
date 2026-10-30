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
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a spelling names the declaration written under it, in its own document too")
    func ownDeclarationIsSpelledQualified() async throws {
        // Given. `first` calls its own `helper` as `First.helper`, and `second`
        // declares a `helper` of its own, which is `Second.helper`
        let first = try loader.loadDocument([
            "procedures": [
                "First.entry": [
                    "returns": "Any",
                    "body": [["let": "said", "value": ["call": ["procedure": "First.helper"]]], ["value": ["return": ["dictionary": [["result", ["ref": "said"]]]]]]]
                ],
                "First.helper": [
                    "returns": "Any",
                    "body": [["let": "done", "value": "from first"], ["value": ["return": ["dictionary": [["said", ["ref": "done"]]]]]]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "procedures": [
                "Second.helper": [
                    "returns": "Any",
                    "body": [["let": "done", "value": "from second"], ["value": ["return": ["dictionary": [["said", ["ref": "done"]]]]]]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "First.entry")

        // Then
        #expect(outputs.dictionaryValue?["result"] == .dictionary(["said": .string("from first")]))
    }

    @Test("a bare name for another module's procedure is refused at the build")
    func aBareNameForAnotherModulesProcedureIsRefused() async throws {
        // Given
        let caller = try loader.loadDocument([
            "imports": ["greet"],
            "procedures": [
                "Caller.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "greet"]]], ["value": ["return": ["dictionary": [["result", ["ref": "said"]]]]]]]
                ]
            ]
        ])
        let library = try loader.loadDocument([
            "procedures": [
                "Greeting.greet": [
                    "body": [["let": "done", "value": "hello"], ["value": ["return": ["dictionary": [["said", ["ref": "done"]]]]]]]
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
                    "returns": "Any",
                    "body": [["let": "said", "value": ["call": ["procedure": "Second.helper"]]], ["value": ["return": ["dictionary": [["result", ["ref": "said"]]]]]]]
                ],
                "First.helper": [
                    "returns": "Any",
                    "body": [["let": "done", "value": "from first"], ["value": ["return": ["dictionary": [["said", ["ref": "done"]]]]]]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "procedures": [
                "Second.helper": [
                    "returns": "Any",
                    "body": [["let": "done", "value": "from second"], ["value": ["return": ["dictionary": [["said", ["ref": "done"]]]]]]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "First.entry")

        // Then
        #expect(outputs.dictionaryValue?["result"] == .dictionary(["said": .string("from second")]))
    }

    @Test("a constant is a name bound to a value, folded before any run")
    func constantsFoldAtTheBuild() async throws {
        // Given
        let sut = try loader.loadDocument([
            "const": ["greeting": "hello", "limit": 3],
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "body": [["let": "said", "value": ["ref": "greeting"]], ["value": ["return": ["dictionary": [["result", ["ref": "said"]], ["cap", ["ref": "limit"]]]]]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs.dictionaryValue?["result"] == .string("hello"))
        #expect(outputs.dictionaryValue?["cap"] == .int(3))
    }

    @Test("a constant may name another declared beside it, but not one that names it back")
    func constantsMayComposeButNotCycle() async throws {
        // Given
        let composed = try loader.loadDocument([
            "imports": ["Standard.Text.joined", "Standard.Text.text"],
            "const": [
                "host": "example.com",
                "url": ["call": ["procedure": "Standard.Text.joined", "arguments": [["https://", ["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "host"]]]], "/api"], ""]]]
            ],
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "body": [["let": "seen", "value": ["ref": "url"]], ["value": ["return": ["dictionary": [["result", ["ref": "seen"]]]]]]]
                ]
            ]
        ])

        // When / Then
        let outputs = try await run(composed)

        #expect(outputs.dictionaryValue?["result"] == .string("https://example.com/api"))

        #expect(throws: ValidationError.self) {
            try loader.loadDocument([
                "const": ["a": ["ref": "b"], "b": ["ref": "a"]],
                "procedures": ["entry": ["body": [["let": "seen", "value": ["ref": "a"]]]]]
            ])
        }
    }

    @Test("a statement may introduce a name the module bound")
    func aStatementMayShadowAConstant() throws {
        // Given. A procedure's body stands inside its document, so its name is
        // the body's own
        let fixture: Value = [
            "const": ["limit": 3],
            "procedures": ["entry": ["body": [["let": "limit", "value": 4]]]]
        ]

        // When / Then
        try validated(try loader.loadDocument(fixture))
    }

    @Test("a document declares a contract, and a procedure reaches it through the contract's name")
    func aDocumentDeclaresAContract() async throws {
        // Given. Two types that describe themselves, and one procedure that knows
        // neither
        let sut = try loader.loadDocument([
            "types": [
                "Bank.Account": [
                    "struct": ["balance": "Int"],
                    "satisfies": ["App.Describable"],
                    "procedures": [
                        "describe": [
                            "parameters": [["name": "of", "type": "Bank.Account"]],
                            "returns": "String",
                            "body": [["value": ["return": "an account"]]]
                        ]
                    ]
                ],
                "Bank.Card": [
                    "struct": ["last": "String"],
                    "satisfies": ["App.Describable"],
                    "procedures": [
                        "describe": [
                            "parameters": [["name": "of", "type": "Bank.Card"]],
                            "returns": "String",
                            "body": [["value": ["return": "a card"]]]
                        ]
                    ]
                ]
            ],
            "contracts": [
                "App.Describable": [
                    "procedures": [
                        "describe": ["parameters": [["name": "of", "type": "Self"]], "returns": "String"]
                    ]
                ]
            ],
            "procedures": [
                "entry": [
                    "returns": "Any",
                    "failing": ["cast_refused"],
                    "body": [
                        [
                            "let": "card",
                            "value": ["as": ["of": ["struct": ["last": "42"]], "type": "Bank.Card"]]
                        ],
                        ["value": ["return": ["dictionary": [["result", ["call": ["procedure": "App.tell", "arguments": [["ref": "card"]]]]]]]]]
                    ]
                ],
                "App.tell": [
                    "parameters": [["name": "it", "type": "some T: App.Describable"]],
                    "returns": "String",
                    "body": [["value": ["return": ["call": ["procedure": "App.Describable.describe", "arguments": [["ref": "it"]]]]]]]
                ]
            ]
        ])

        // When / Then
        let outputs = try await run(sut, entry: "entry")

        #expect(outputs.dictionaryValue?["result"] == .string("a card"))
    }

    // MARK: - Public
    // MARK: - Private
    private func validated(_ module: Module) throws -> Module {
        try Validator().validate(module)

        return module
    }
}

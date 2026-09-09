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

// A module declares more than procedures, and what it declares is its own. A
// corpus whose names all went into one shared space could not grow without them
// colliding, and a value used in three places had to be written three times.
@Suite("What a module declares")
struct ModuleDeclarationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a spelling names the declaration written under it, in its own document too")
    func ownDeclarationIsSpelledQualified() async throws {
        // Given. `first` calls its own `helper` as `first.helper`, and `second`
        // declares a `helper` of its own, which is `second.helper`
        let first = try loader.loadDocument([
            "procedures": [
                "first.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "first.helper"]]]],
                    "result": ["result": ["ref": "said"]]
                ],
                "first.helper": [
                    "body": [["let": "done", "value": "from first"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "procedures": [
                "second.helper": [
                    "body": [["let": "done", "value": "from second"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "first.entry")

        // Then
        #expect(outputs["result"] == .dictionary(["said": .string("from first")]))
    }

    @Test("a bare name for another module's word is refused at the link")
    func aBareNameForAnotherModulesWordIsRefused() throws {
        // Given
        let caller = try loader.loadDocument([
            "imports": ["greet"],
            "procedures": [
                "caller.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "greet"]]]],
                    "result": ["result": ["ref": "said"]]
                ]
            ]
        ])
        let library = try loader.loadDocument([
            "procedures": [
                "greeting.greet": [
                    "body": [["let": "done", "value": "hello"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])

        // When / Then
        #expect {
            try Linker().link([caller, library], entry: "caller.entry")
        } throws: { error in
            "\(error)".contains("sends 'greet', which no module in this link declares")
        }
    }

    @Test("a spelling reaches the declaration under it, whichever document wrote it")
    func qualifiedNameReachesAcross() async throws {
        // Given. `first` has a `helper` of its own and asks for the other one
        let first = try loader.loadDocument([
            "imports": ["second.helper"],
            "procedures": [
                "first.entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "second.helper"]]]],
                    "result": ["result": ["ref": "said"]]
                ],
                "first.helper": [
                    "body": [["let": "done", "value": "from first"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "procedures": [
                "second.helper": [
                    "body": [["let": "done", "value": "from second"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "first.entry")

        // Then
        #expect(outputs["result"] == .dictionary(["said": .string("from second")]))
    }

    @Test("a constant is a name bound to a value, settled before any run")
    func constantsFoldAtLink() async throws {
        // Given
        let sut = try loader.loadDocument([
            "const": ["greeting": "hello", "limit": 3],
            "procedures": [
                "entry": [
                    "body": [["let": "said", "value": ["ref": "greeting"]]],
                    "result": ["result": ["ref": "said"], "cap": ["ref": "limit"]]
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
            "imports": ["std.text.joined", "std.text.text"],
            "const": [
                "host": "example.com",
                "url": ["format": "https://${host}/api", "with": ["host": ["ref": "host"]]]
            ],
            "procedures": [
                "entry": [
                    "body": [["let": "seen", "value": ["ref": "url"]]],
                    "result": ["result": ["ref": "seen"]]
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

        #expect(throws: LinkError.self) {
            try Linker().link([cyclic], entry: entryName)
        }
    }

    @Test("a statement may not reintroduce a name the module bound")
    func constantsCannotBeShadowed() {
        // Given. Linking folds a reference to a constant into its value, so a
        // second reading of the same spelling could never be true
        let fixture: Value = [
            "const": ["limit": 3],
            "procedures": ["entry": ["body": [["let": "limit", "value": 4]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadDocument(fixture).validated()
        }
    }

    @Test("a document declares a contract, and a word reaches it through the contract's name")
    func aDocumentDeclaresAContract() async throws {
        // Given. Two shapes that describe themselves, and one word that knows
        // neither
        let sut = try loader.loadDocument([
            "types": [
                "bank.Account": ["balance": "int"],
                "bank.Card": ["last": "string"]
            ],
            "contracts": [
                "app.Describable": ["describe": ["returns": "string"]]
            ],
            "satisfies": [
                "bank.Account": ["app.Describable"],
                "bank.Card": ["app.Describable"]
            ],
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "let": "card",
                            "value": ["as": "bank.Card", "of": ["last": "42"]]
                        ]
                    ],
                    "result": ["result": ["call": ["of": ["ref": "card"], "procedure": "app.tell"]]]
                ],
                "app.tell": [
                    "receiver": "it",
                    "parameters": ["it": "some T"],
                    "bounds": ["T": "app.Describable"],
                    "returns": "string",
                    "result": ["call": ["of": ["ref": "it"], "procedure": "app.Describable.describe"]]
                ],
                "bank.Account.describe": [
                    "receiver": "of",
                    "parameters": ["of": "bank.Account"],
                    "returns": "string",
                    "result": "an account"
                ],
                "bank.Card.describe": [
                    "receiver": "of",
                    "parameters": ["of": "bank.Card"],
                    "returns": "string",
                    "result": "a card"
                ]
            ]
        ])

        // When / Then
        let outputs = try await run(sut, entry: "entry")

        #expect(outputs["result"] == .string("a card"))
    }

}

private extension Module {
    func validated() throws -> Module {
        try Validator().validate(self)

        return self
    }
}

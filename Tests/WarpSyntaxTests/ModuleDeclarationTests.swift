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
    @Test("a name written inside a module is spelled with the module's name")
    func ownDeclarationIsSpelledQualified() async throws {
        // Given — both modules declare `helper`, and both call it unqualified
        let first = try loader.loadDocument([
            "name": "first",
            "procedures": [
                "entry": [
                    "body": [["id": "said", "call": ["procedure": "first.helper"]]],
                    "result": ["result": ["ref": "said"]]
                ],
                "helper": [
                    "body": [["id": "done", "value": "from first"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "name": "second",
            "procedures": [
                "helper": [
                    "body": [["id": "done", "value": "from second"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "first.entry")

        // Then
        #expect(outputs["result"] == .object(["said": .string("from first")]))
    }

    @Test("a bare name for another module's word is refused at the link")
    func aBareNameForAnotherModulesWordIsRefused() throws {
        // Given
        let caller = try loader.loadDocument([
            "imports": ["greet"],
            "name": "caller",
            "procedures": [
                "entry": [
                    "body": [["id": "said", "call": ["procedure": "greet"]]],
                    "result": ["result": ["ref": "said"]]
                ]
            ]
        ])
        let library = try loader.loadDocument([
            "name": "greeting",
            "procedures": [
                "greet": [
                    "body": [["id": "done", "value": "hello"]],
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

    @Test("a qualified name reaches past what the writing module declares")
    func qualifiedNameReachesAcross() async throws {
        // Given — `first` has a `helper` of its own and asks for the other one
        let first = try loader.loadDocument([
            "imports": ["second.helper"],
            "name": "first",
            "procedures": [
                "entry": [
                    "body": [["id": "said", "call": ["procedure": "second.helper"]]],
                    "result": ["result": ["ref": "said"]]
                ],
                "helper": [
                    "body": [["id": "done", "value": "from first"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])
        let second = try loader.loadDocument([
            "name": "second",
            "procedures": [
                "helper": [
                    "body": [["id": "done", "value": "from second"]],
                    "result": ["said": ["ref": "done"]]
                ]
            ]
        ])

        // When
        let outputs = try await run([first, second], entry: "first.entry")

        // Then
        #expect(outputs["result"] == .object(["said": .string("from second")]))
    }

    @Test("a constant is a name bound to a value, settled before any run")
    func constantsFoldAtLink() async throws {
        // Given
        let sut = try loader.loadDocument([
            "const": ["greeting": "hello", "limit": 3],
            "procedures": [
                "entry": [
                    "body": [["id": "said", "value": ["ref": "greeting"]]],
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
                    "body": [["id": "seen", "value": ["ref": "url"]]],
                    "result": ["result": ["ref": "seen"]]
                ]
            ]
        ])
        let cyclic = try loader.loadDocument([
            "const": ["a": ["ref": "b"], "b": ["ref": "a"]],
            "procedures": ["entry": ["body": [["id": "seen", "value": ["ref": "a"]]]]]
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
        // Given — linking folds a reference to a constant into its value, so a
        // second reading of the same spelling could never be true
        let fixture: Value = [
            "const": ["limit": 3],
            "procedures": ["entry": ["body": [["id": "limit", "value": 4]]]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadDocument(fixture).validated()
        }
    }
}

private extension Module {
    func validated() throws -> Module {
        try Validator().validate(self)

        return self
    }
}

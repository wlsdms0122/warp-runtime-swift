//
//  ReadingErrorTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite
struct ReadingErrorTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let identity = Identity(Array(repeating: 0xab, count: 32))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document refused while being read says which document it was")
    func aReadingSaysWhichDocument() throws {
        // Given — a caller reading four documents into one link holds the only
        // answer to which file to open, and a refusal that names none sends it
        // opening all four
        let fixture: Value = [
            "warp": 1,
            "needs": [],
            "name": "wallet",
            "procedures": ["entry": ["body": [["id": "sent", "call": ["procedure": "plus"]]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
        #expect(error?.place?.document.namespace == "wallet")
    }

    @Test("the steps of a reading's refusal are the document's own keys")
    func aReadingWalksTheDocumentsKeys() throws {
        // Given — the address decoding reached, spelled the way every other
        // stage spells one, so an author follows the same words either way: a
        // statement wears the name it wrote, which is what validation and the
        // link call it
        let fixture: Value = [
            "warp": 1,
            "needs": [],
            "name": "wallet",
            "procedures": ["entry": ["body": [["id": "broken", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.rendered == "wallet@abababababab/procedures.entry.body.broken[0]")
    }

    @Test("a declared name that reads as a number is a key and not a position")
    func aNumericNameIsAKey() throws {
        // Given — a coding key made for a dictionary carries the number its
        // spelling parses to, and `procedures[12]` is an address no document
        // has: what the document holds where the walk is settles which it is
        let fixture: Value = [
            "warp": 1,
            "needs": [],
            "name": "wallet",
            "procedures": ["12": ["body": [["id": "broken", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "wallet/procedures.12.body.broken[0]")
    }

    @Test("a statement that writes an empty name is a statement with no name")
    func anEmptyStatementNameIsNoName() throws {
        // Given — the two ways of writing nothing spell the same, and a step
        // rendering an empty name puts a dot in front of nothing
        let fixture: Value = [
            "warp": 1,
            "needs": [],
            "name": "wallet",
            "procedures": ["entry": ["body": [["id": "", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "wallet/procedures.entry.body[0]")
    }

    @Test("a document that writes an empty name is a document with no name")
    func anEmptyNamespaceIsNoNamespace() throws {
        // Given — the same rule one step out. What spells the document is
        // assembled at every stage, and an empty name is not one of them.
        let fixture: Value = [
            "warp": 1,
            "needs": [],
            "name": "",
            "procedures": ["entry": ["body": [["id": "sent", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.document.namespace == nil)
        #expect(error?.place?.rendered == "abababababab/procedures.entry.body.sent[0]")
    }

    @Test("a form that refuses in its own words still says which document")
    func aFormsOwnRefusalIsPlaced() throws {
        // Given — a form reading an expression refuses with the expression
        // reader's own error, which carries no place of its own. It leaves
        // through the door that says every reading is placed, so it is.
        let fixture: Value = [
            "warp": 1,
            "needs": [],
            "name": "wallet",
            "procedures": ["entry": ["body": [["return": ["ref": [1]]]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
        #expect(error?.place?.rendered == "wallet@abababababab/procedures.entry.body[0].return")
    }

    @Test("a document refused for the list it does not write is refused about itself")
    func aMissingManifestIsAboutTheDocument() throws {
        // Given — nothing inside the document is wrong, so there is no step to
        // walk and the document alone is the whole address
        let fixture: Value = [
            "warp": 1,
            "name": "wallet",
            "procedures": ["entry": ["result": "hello"]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.steps.isEmpty == true)
        #expect(error?.description.hasPrefix("wallet@abababababab: ") == true)
    }

    @Test("a fragment is refused about no document, and says so by naming none")
    func aFragmentNamesNoDocument() throws {
        // Given — what a fragment will be part of is the caller's, and a reader
        // that named a document here would be naming one it was never shown
        let error = #expect(throws: ReadingError.self) {
            try loader.statement(from: ["id": "broken", "value": "x", "fallbck": "y"])
        }

        // Then
        #expect(error?.place?.document == .assembled)
        #expect(error?.description.hasPrefix(":") == false)
    }

    // MARK: - Public
    // MARK: - Private
}

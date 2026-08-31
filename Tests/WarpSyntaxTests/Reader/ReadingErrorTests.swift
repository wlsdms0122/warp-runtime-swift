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
        // stage spells one, so an author follows the same words either way
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
        #expect(error?.place?.rendered == "wallet@abababababab/procedures.entry.body[0]")
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

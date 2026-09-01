//
//  VocabularyTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// Vocabulary is modules — not a second container beside them with its own
// registration, namespace and lookup order. These are the facts that follow.
@Suite("Vocabulary is modules")
struct VocabularyTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a word is a declaration, so a module can add one")
    func moduleAddsWords() async throws {
        // Given — `count` and `contains` are declarations, not language
        // structure; anyone adds their own the same way
        let extra = try Module(
            name: "extra",
            procedures: [
                "head": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .array(.any))],
                        returns: .any
                    ),
                    implementation: .query(FirstQuery())
                ),
                "longerThan": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string),
                            "value": Parameter(type: .int)
                        ],
                        returns: .bool
                    ),
                    implementation: .query(LongerThanQuery())
                )
            ]
        )
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                ["var": "verdict"],
                [
                    "branch": [
                        "when": ["of": ["ref": "names.first"], "longerThan": 3],
                        "then": [["set": "verdict", "value": "long"]]
                    ]
                ]
            ],
            "result": ["result": ["ref": "verdict"], "head": ["ref": "names.first"]]
        ], importing: ["longerThan"])

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("spectacle"), .string("ok")])],
            vocabulary: Module.standard + [.testing, extra]
        )

        // Then
        #expect(outputs["result"] == .string("long"))
        #expect(outputs["head"] == .string("spectacle"))
    }

    @Test("a word left out of the link is a word that does not exist")
    func omittedVocabularyDoesNotResolve() throws {
        // Given — nothing is privileged, so the standard module is a file like
        // any other and leaving it out means leaving out what it declares
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                ["id": "how_many", "value": ["ref": "names.count"]],
                ["id": "said", "call": ["procedure": "count"]]
            ]
        ], importing: ["count"])

        // When / Then
        #expect(throws: LinkError.self) {
            try loader.language.link([sut], entry: entryName)
        }
    }

    @Test("two modules declaring one path word is refused, because a path names no module")
    func ambiguousDerivationRefused() throws {
        // Given — `${x.count}` writes no module, so there is no spelling that
        // would tell two of them apart
        let rival = try Module(
            name: "rival",
            procedures: [
                "count": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .any)],
                        returns: .int
                    ),
                    implementation: .query(FirstQuery())
                )
            ]
        )
        let sut = try loader.loadProcedure(["body": [["id": "done", "value": "end"]]])

        // When / Then
        #expect(throws: LinkError.self) {
            try loader.language.link([sut] + Module.standard + [rival], entry: entryName)
        }
    }

    @Test("a claimed construct key is never silently replaced")
    func claimedConstructKeyRejected() {
        // Given / When / Then — nobody may silently replace `loop`
        #expect(throws: ValidationError.self) {
            try ConstructRegistry.standard.registering(LoopForm.self)
        }
    }
}

// MARK: - Words a test brings

private struct FirstQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(elements) = question.receiver else { return nil }

        return elements.first
    }

    // MARK: - Private
}

private struct LongerThanQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question) throws -> Value? {
        guard
            case let .string(text) = question.receiver,
            case let .int(limit) = question["value"]
        else {
            return nil
        }

        return .bool(text.count > limit)
    }

    // MARK: - Private

}

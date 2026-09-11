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
import WarpStandard

// Vocabulary is modules, not a second container beside them with its own
// registration, namespace and lookup order. These are the facts that follow.
@Suite("Vocabulary is modules")
struct VocabularyTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a word is a declaration, so a module can add one")
    func moduleAddsWords() async throws {
        // Given. `count` and `contains` are declarations, not language
        // structure; anyone adds their own the same way
        let extra = try Module(
            procedures: [
                "extra.head": Procedure(
                    signature: Signature(of: FirstQuery.self, receiver: .of, returns: .any),
                    implementation: .query(FirstQuery())
                ),
                "extra.longerThan": Procedure(
                    signature: Signature(
                        of: LongerThanQuery.self,
                        receiver: .of,
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
                    "value": ["conditional": [
                        "when": ["of": ["ref": "names.first"], "longerThan": 3],
                        "then": [["set": "verdict", "value": "long"]]
                    ]
                ]]
            ],
            "result": ["result": ["ref": "verdict"], "head": ["ref": "names.first"]]
        ], importing: ["extra.longerThan", "std.collection.first"])

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
        // Given. Nothing is privileged, so the standard module is a file like
        // any other and leaving it out means leaving out what it declares
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                ["let": "how_many", "value": ["ref": "names.count"]],
                ["let": "said", "value": ["call": ["procedure": "std.collection.count"]]]
            ]
        ], importing: ["std.collection.count"])

        // When / Then
        #expect(throws: BuildError.self) {
            try Builder().build([sut], entry: entryName)
        }
    }

    @Test("two modules declaring one path word is refused, because a path names no module")
    func ambiguousDerivationRefused() throws {
        // Given. `${x.count}` writes no module, so there is no spelling that
        // would tell two of them apart
        let rival = try Module(
            procedures: [
                "rival.count": Procedure(
                    signature: Signature(of: FirstQuery.self, receiver: .of, returns: .int),
                    implementation: .query(FirstQuery())
                )
            ]
        )
        let sut = try loader.loadProcedure([
            "parameters": ["x": "array<string>"],
            "body": [["let": "size", "value": ["ref": "x.count"]]]
        ], importing: ["rival.count", "std.collection.count"])

        // When / Then
        #expect(throws: BuildError.self) {
            try Builder().build([sut] + Module.standard + [rival], entry: entryName)
        }
    }

    @Test("a claimed construct key is never silently replaced")
    func claimedConstructKeyRejected() {
        // Given / When / Then. Nobody may silently replace `loop`
        #expect(throws: ValidationError.self) {
            try ConstructRegistry.standard.registering(LoopForm.self)
        }
    }
}

// MARK: - Words a test brings

private struct FirstQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .array(.any)) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        guard case let .array(elements) = question.receiver else { return nil }

        return elements.first
    }

    // MARK: - Private
}

private struct LongerThanQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of
        case value

        var name: Name {
            switch self {
            case .of:
                return "of"

            case .value:
                return "value"
            }
        }

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(type: .string)

            case .value:
                return Parameter(type: .int)
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        guard
            case let .string(text) = question.receiver,
            case let .int(limit) = question[.value]
        else {
            return nil
        }

        return .bool(text.count > limit)
    }

    // MARK: - Private

}

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
    @Test("a procedure is a declaration, so a module can add one")
    func moduleAddsProcedures() async throws {
        // Given. `count` and `contains` are declarations, not language
        // structure; anyone adds their own the same way
        let extra = try Module(
            procedures: [
                "extra.head": Procedure(
                    signature: Signature(of: FirstQuery.self, returns: .any),
                    implementation: .query(FirstQuery())
                ),
                "extra.longerThan": Procedure(
                    signature: Signature(
                        of: LongerThanQuery.self,
                        returns: .bool
                    ),
                    implementation: .query(LongerThanQuery())
                )
            ]
        )
        let sut = try await loader.loadProcedure([
            "parameters": [["name": "names", "type": "array<string>"]],
            "body": [
                ["var": "verdict"],
                ["let": "head", "value": ["call": ["procedure": "std.collection.first", "arguments": [["ref": "names"]]]]],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "head"], "longerThan": 3],
                        "then": [["set": "verdict", "value": "long"]]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "verdict"], "head": ["ref": "head"]]]
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

    @Test("a procedure left out of the link is a procedure that does not exist")
    func omittedVocabularyDoesNotResolve() async throws {
        // Given. Nothing is privileged, so the standard module is a file like
        // any other and leaving it out means leaving out what it declares
        let sut = try await loader.loadProcedure([
            "parameters": [["name": "names", "type": "array<string>"]],
            "body": [
                ["let": "said", "value": ["call": ["procedure": "std.collection.count"]]]
            ]
        ], importing: ["std.collection.count"])

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut])
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

// MARK: - Procedures a test brings

private struct FirstQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of

        var declared: Parameter { Parameter(name: "of", type: .array(.any)) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard case let .array(elements) = question[.of] else { return nil }

        return elements.first
    }

    // MARK: - Private
}

private struct LongerThanQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of
        case value

        var declared: Parameter {
            switch self {
            case .of:
                return Parameter(name: "of", type: .string)

            case .value:
                return Parameter(name: "value", type: .int)
            }
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        guard
            case let .string(text) = question[.of],
            case let .int(limit) = question[.value]
        else {
            return nil
        }

        return .bool(text.count > limit)
    }

    // MARK: - Private

}

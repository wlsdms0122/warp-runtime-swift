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
import WarpTestSupport

// Vocabulary is modules, not a second container beside them with its own
// registration, namespace and lookup order. These are the facts that follow.
@Suite("Vocabulary is modules")
struct VocabularyTests {
    private struct FirstQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .array(.any)) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            guard case let .array(elements) = question[.of] else {
                throw ExecutionError("Extra.head asks an array")
            }

            return elements.first ?? .null
        }

        // MARK: - Private
    }

    private struct LongerThanQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of
            case value

            // MARK: - Property
            var declared: Parameter {
                switch self {
                case .of:
                    return Parameter(name: "of", type: .string)

                case .value:
                    return Parameter(name: "value", type: .int)
                }
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            guard
                case let .string(text) = question[.of],
                case let .int(limit) = question[.value]
            else {
                throw ExecutionError("Extra.longerThan asks a String and an Int")
            }

            return .bool(text.count > limit)
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure is a declaration, so a module can add one")
    func moduleAddsProcedures() async throws {
        // Given. `count` and `contains` are declarations, not language
        // structure; anyone adds their own the same way
        let extra = try Module(
            procedures: [
                "Extra.head": Procedure(
                    signature: Signature(of: FirstQuery.self, returns: .any),
                    implementation: .query(FirstQuery())
                ),
                "Extra.longerThan": Procedure(
                    signature: Signature(
                        of: LongerThanQuery.self,
                        returns: .bool,
                        constness: .const
                    ),
                    implementation: .query(LongerThanQuery())
                )
            ]
        )
        let sut = try loader.loadProcedure([
            "returns": "Any",
            "parameters": [["name": "names", "type": "Array<String>"]],
            "body": [
                ["var": "verdict"],
                ["let": "head", "value": ["call": ["procedure": "Standard.Collection.first", "arguments": [["ref": "names"]]]]],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "head"], "longerThan": 3],
                        "then": [["set": "verdict", "value": "long"]]
                    ]
                ]]
            ],
            "result": ["dictionary": [["result", ["ref": "verdict"]], ["head", ["ref": "head"]]]]
        ], importing: ["Extra.longerThan", "Standard.Collection.first"])

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("spectacle"), .string("ok")])],
            vocabulary: Module.standard + [.testing, extra]
        )

        // Then
        #expect(outputs.map?["result"] == .string("long"))
        #expect(outputs.map?["head"] == .string("spectacle"))
    }

    @Test("a procedure left out of the link is a procedure that does not exist")
    func omittedVocabularyDoesNotResolve() async throws {
        // Given. Nothing is privileged, so the standard module is a file like
        // any other and leaving it out means leaving out what it declares
        let sut = try loader.loadProcedure([
            "parameters": [["name": "names", "type": "Array<String>"]],
            "body": [
                ["let": "said", "value": ["call": ["procedure": "Standard.Collection.count"]]]
            ]
        ], importing: ["Standard.Collection.count"])

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut])
        }
    }

    @Test("a claimed construct key is never silently replaced")
    func claimedConstructKeyRejected() {
        // Given / When / Then. Nobody may silently replace `loop`
        #expect(throws: ConstructRegistryError.self) {
            try ConstructRegistry.standard.registering(LoopForm.self)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

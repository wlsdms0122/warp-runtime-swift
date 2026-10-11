//
//  ConcurrentTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

// Running at once, as a document spells it: closures handed to the
// `Standard.Concurrent` procedures. There is no construct here. A fan-out is a call, and
// what makes it safe is what a closure already is.
@Suite("Running at once, as a document spells it")
struct ConcurrentTests {
    // Probe environment counting how many pieces pass through the isolation hook.
    private final class IsolationBoundaryProbe: Environment, @unchecked Sendable {
        // MARK: - Property
        private let lock = NSLock()
        private var count = 0

        var isolatedCount: Int {
            lock.withLock { count }
        }

        // MARK: - Initializer
        // MARK: - Public
        func isolateConcurrentWork<T: Sendable>(
            _ work: @Sendable () async throws -> T
        ) async throws -> T {
            lock.withLock { count += 1 }

            return try await work()
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("the environment's isolation boundary wraps every piece")
    func environmentIsolatesEachPiece() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "let": "par",
                    "value": ["call": [
                        "procedure": "Standard.Concurrent.allKeyed",
                        "arguments": [
                            ["dictionary": [["left", ["closure": ["result": 1]]], ["right", ["closure": ["result": 2]]]]]
                        ]
                    ]
                ]]
            ],
            "result": ["dictionary": [["result", ["ref": "par"]]]]
        ], importing: ["Standard.Concurrent.allKeyed"])
        let boundary = IsolationBoundaryProbe()

        // When
        let outputs = try await run(spec, environment: boundary)

        // Then. Every piece walked through the environment's isolation boundary
        #expect(boundary.isolatedCount == 2)
        #expect(outputs["result"] == .dictionary(["left": .int(1), "right": .int(2)]))
    }

    @Test("all-recoverable failures rescue")
    func allRecoverableFailuresRescue() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "let": "par",
                    "value": ["attempt": [
                        "body": [
                            [
                                "let": "par",
                                "value": ["call": [
                                    "procedure": "Standard.Concurrent.allKeyed",
                                    "arguments": [
                                        ["dictionary": [["fine", ["closure": ["result": "ok"]]], ["fragile", [
                                                "closure": [
                                                    "body": [["let": "boom", "value": ["fail": true]]],
                                                    "result": ["ref": "boom"]
                                                ]
                                            ]]]]
                                    ]
                                ]
                            ]]
                        ],
                        "rescue": [
                            "body": [["let": "recovery", "value": "recovered"]],
                            "result": ["ref": "recovery"]
                        ]
                    ]
                ]]
            ],
            "result": ["dictionary": [["result", ["ref": "par"]]]]
        ], importing: ["Standard.Concurrent.allKeyed", "Test.fail"])

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.testing])

        // Then
        #expect(outputs["result"] == .string("recovered"))
    }

    @Test("one piece's author mistake propagates the composite")
    func anyFatalPiecePropagates() async throws {
        // Given. One author mistake makes the composite an author mistake
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "let": "par",
                    "value": ["attempt": [
                        "body": [
                            [
                                "let": "par",
                                "value": ["call": [
                                    "procedure": "Standard.Concurrent.allKeyed",
                                    "arguments": [
                                        ["dictionary": [["fragile", [
                                                "closure": [
                                                    "body": [["let": "boom", "value": ["fail": true]]],
                                                    "result": ["ref": "boom"]
                                                ]
                                            ]], ["broken", [
                                                "closure": [
                                                    "body": [["let": "boom", "value": ["fail": false]]],
                                                    "result": ["ref": "boom"]
                                                ]
                                            ]]]]
                                    ]
                                ]
                            ]]
                        ],
                        "rescue": ["body": [["let": "recovery", "value": "recovered"]]]
                    ]
                ]]
            ]
        ], importing: ["Standard.Concurrent.allKeyed", "Test.fail"])

        // When / Then
        await #expect(throws: TestFatalError.self) {
            try await run(spec, vocabulary: Module.standard + [.testing])
        }
    }

    @Test("map walks a collection and answers in its order")
    func mapWalksACollection() async throws {
        // Given. The closure asks for the element under `item`, the same name
        // the sequential walk reads it by
        let sut = try loader.loadProcedure([
            "parameters": [["name": "names", "type": "Array<String>"]],
            "body": [
                [
                    "let": "greeted",
                    "value": ["call": [
                        "procedure": "Standard.Concurrent.map",
                        "arguments": [
                            ["ref": "names"],
                            [
                                "closure": [
                                    "parameters": [["name": "item", "type": "String"], ["name": "index", "type": "Int"]],
                                    "body": [
                                        [
                                            "let": "line",
                                            "value": [
                                                "format": "hello, ${who}",
                                                "with": ["who": ["ref": "item"]]
                                            ]
                                        ]
                                    ],
                                    "result": ["ref": "line"]
                                ]
                            ]
                        ]
                    ]
                ]]
            ],
            "result": ["dictionary": [["result", ["ref": "greeted"]]]]
        ], importing: ["Standard.Text.joined", "Standard.Concurrent.map", "Standard.Text.text"])

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(outputs["result"] == .array([.string("hello, a"), .string("hello, b")]))
    }

    @Test("first answers whichever piece succeeds")
    func firstAnswersTheFirstSuccess() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [
                [
                    "let": "either",
                    "value": ["call": [
                        "procedure": "Standard.Concurrent.first",
                        "arguments": [
                            [
                                [
                                    "closure": [
                                        "body": [["let": "boom", "value": ["fail": true]]],
                                        "result": ["ref": "boom"]
                                    ]
                                ],
                                ["closure": ["result": "answered"]]
                            ]
                        ]
                    ]
                ]]
            ],
            "result": ["dictionary": [["result", ["ref": "either"]]]]
        ], importing: ["Test.fail", "Standard.Concurrent.first"])

        // When
        let outputs = try await run(sut, vocabulary: Module.standard + [.testing])

        // Then
        #expect(outputs["result"] == .string("answered"))
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  LoopTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

@Suite("A loop repeats while its condition holds")
struct LoopTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("loop repeats while its where holds")
    func loopRepeatsWhileConditionHolds() async throws {
        // Given. The loop writes a variable declared outside it and reads its
        // own round index through ${gate.index}
        let spec = try loader.loadProcedure([
            "body": [
                ["var": "latest", "value": 0],
                [
                    "let": "gate",
                    "value": ["loop": [
                        "while": ["of": ["ref": "gate.index"], "notEqual": 3],
                        "body": [["set": "latest", "value": ["ref": "gate.index"]]],
                        "result": ["ref": "latest"]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "gate"]]]
        ], importing: ["std.logic.notEqual"])

        // When
        let outputs = try await run(spec)

        // Then. Rounds 0/1/2 ran; at index 3 the where turned false
        #expect(outputs["result"] == .int(2))
    }

    @Test("a loop runs unbounded, like while")
    func loopRunsUnbounded() async throws {
        // Given. The language carries no budget; the world (here, the
        // condition) ends the repetition
        let spec = try loader.loadProcedure([
            "body": [
                ["var": "latest", "value": 0],
                [
                    "let": "gate",
                    "value": ["loop": [
                        "while": ["of": ["ref": "gate.index"], "notEqual": 7],
                        "body": [["set": "latest", "value": ["ref": "gate.index"]]],
                        "result": ["ref": "latest"]
                    ]
                ]]
            ],
            "result": ["record": ["result": ["ref": "gate"]]]
        ], importing: ["std.logic.notEqual"])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .int(6))
    }

    @Test("a guard key on loop is refused at the load")
    func aGuardKeyIsRefusedAtTheLoad() throws {
        // When / Then. Repetition carries no budget of its own: an author
        // bounds a loop with a counter and a procedure, and the host stops one
        // by cancelling the run. The key is gone rather than ignored.
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "body": [
                    [
                        "let": "gate",
                        "value": ["loop": [
                            "while": ["of": ["ref": "gate.index"], "notEqual": 3],
                            "body": [["let": "noop", "value": "again"]],
                            "guard": 2
                        ]
                    ]]
                ]
            ])
        }
    }

    @Test("an empty-body loop still observes cancellation")
    func emptyBodyObservesCancellation() async throws {
        // Given. An empty body must still observe cancellation, or the host's
        // one lever against a runaway loop stops working
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "let": "gate",
                    "value": ["loop": ["while": ["of": ["ref": "gate.index"], "notEqual": .null], "body": []]
                ]]
            ]
        ], importing: ["std.logic.notEqual"])

        // When
        let task = Task {
            try await run(spec)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // Then
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    @Test("a loop body may rebind an outer id by shadowing")
    func loopRebindsOuterIDByShadowing() throws {
        // Given. The retry-loop idiom rebinds an outer id inside loop steps
        let fixture: Value = [
            "body": [
                ["let": "format", "value": "first"],
                [
                    "let": "gate",
                    "value": ["loop": [
                        "while": ["of": ["ref": "gate.index"], "equal": 0],
                        "body": [["let": "format", "value": "retried"]]
                    ]
                ]]
            ]
        ]

        // When / Then
        #expect(throws: Never.self) {
            try loader.loadProcedure(fixture, importing: ["std.logic.equal"])
        }
    }

    // MARK: - Public
    // MARK: - Private
}

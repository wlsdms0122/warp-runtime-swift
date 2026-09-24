//
//  NotationGateTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// The gates a document meets while it is being read, rather than while it runs.
// Each of these is a message an author will meet, which is the reason they are
// worth pinning: a gate nobody checks can stop refusing, and a message nobody
// checks can stop saying what to do about it.
@Suite("What the reader refuses")
struct NotationGateTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a type that opens an argument it never closes is refused", arguments: [
        "array<string",
        "array<string>>",
        "array<>",
        ""
    ])
    func malformedTypeIsRefused(written: String) {
        // Given / When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure([
                "parameters": [["name": "subject", "type": Value.string(written)]],
                "body": [["let": "done", "value": "end"]]
            ])
        }
    }

    @Test("a body written as something other than a list is refused")
    func bodyMustBeAList() {
        // Given / When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(["body": ["id": "done", "value": "end"]])
        }
    }

    @Test("a statement written as something other than a record is refused")
    func statementMustBeARecord() {
        // Given / When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(["body": ["done"]])
        }
    }

    @Test("a statement decoded without a registry cannot be read at all")
    func statementNeedsARegistry() {
        // Given. The registry travels in the decoder rather than in the data,
        // so a reader reached without one has no way to know what a procedure means
        let decoder = ValueDecoder(value: ["id": "done", "value": "end"], codingPath: [], steps: [], userInfo: [:])

        // When / Then. A reading refuses as a reading wherever it is asked for,
        // and which document it was reading is the door's to say: nothing here
        // went through one, so the refusal names none
        #expect(throws: ReadingError.self) {
            try StatementReader(from: decoder)
        }
    }
}

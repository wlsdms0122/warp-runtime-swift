//
//  ReaderGateTests.swift
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
struct ReaderGateTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a type that opens an argument it never closes is refused", arguments: [
        "Array<String",
        "Array<String>>",
        "Array<>",
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

    @Test("a statement written as something other than a mapping is refused")
    func statementMustBeAMapping() {
        // Given / When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(["body": ["done"]])
        }
    }

    // MARK: - Public
    // MARK: - Private
}

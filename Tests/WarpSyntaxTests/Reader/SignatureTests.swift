//
//  SignatureTests.swift
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

@Suite("How a document spells a signature")
struct SignatureTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a parameter written without a type is read as Any")
    func untypedParameterIsReadAsAny() throws {
        // Given / When. Writing no type is how a document says `Any`
        let sut = try Loader.testing.loadDocument([
            "procedures": [
                "keep": [
                    "parameters": [["name": "subject"]],
                    "body": [["let": "done", "value": ["ref": "subject"]]]
                ]
            ]
        ])

        // Then
        let signature = try #require(sut.procedures["keep"]).signature

        #expect(signature.parameter(named: "subject")?.type == .any)
    }

    @Test("a procedure written without a return type answers Null")
    func untypedReturnAnswersNull() throws {
        // Given / When
        let sut = try Loader.testing.loadDocument([
            "procedures": [
                "quiet": ["body": [["let": "done", "value": "end"]]],
                "loud": ["returns": "Any", "body": [["let": "done", "value": "end"]]]
            ]
        ])

        // Then
        #expect(try #require(sut.procedures["quiet"]).signature.returns == .null)
        #expect(try #require(sut.procedures["loud"]).signature.returns == .any)
    }

    // MARK: - Public
    // MARK: - Private
}

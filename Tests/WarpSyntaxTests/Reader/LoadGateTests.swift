//
//  LoadGateTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite("What a load refuses before anything runs")
struct LoadGateTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("an unknown step key is rejected at load")
    func unknownStepKeyRejected() {
        // Given
        let fixture: Value = ["body": [["let": "broken", "value": "x", "fallbck": "y"]]]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a guard written on the envelope is rejected, because conditional is where a guard goes")
    func envelopeGuardRejected() {
        // Given. No language spells a guard as a modifier on a statement. `if x
        // { some() }` is the form, and that is `conditional`, so the envelope reads
        // `when:` as the unknown key it is.
        let fixture: Value = [
            "parameters": [["name": "kind", "type": "String"]],
            "body": [
                [
                    "let": "only-a",
                    "when": ["of": ["ref": "kind"], "equal": "a"],
                    "value": "taken"
                ]
            ]
        ]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a step declaring two actions is rejected")
    func doubleActionStepRejected() {
        // Given
        let fixture: Value = ["body": [["let": "broken", "value": "x", "fail": true]]]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("an unknown reference head is caught at load, not at run")
    func unknownReferenceHeadRejected() {
        // Given. Forward references and typos surface at load, not at run
        let fixture: Value = [
            "body": [["let": "early", "value": ["ref": "later"]], ["let": "later", "value": "x"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("duplicate sibling step ids are rejected")
    func duplicateSiblingIDsRejected() {
        // Given
        let fixture: Value = ["body": [["let": "twin", "value": "x"], ["let": "twin", "value": "y"]]]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a step id colliding with a declared input is rejected")
    func parameterCollisionRejected() {
        // Given. The signature and the body are one scope, so the name the
        // signature introduced cannot be introduced again
        let fixture: Value = [
            "parameters": [["name": "name", "type": "String"]],
            "body": [["let": "name", "value": "x"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("an empty rescue is rejected")
    func emptyRescueRejected() {
        // Given. An attempt whose rescue produces nothing swallows the failure
        // into null without a trace; the honest form is no attempt at all
        let fixture: Value = [
            "body": [
                [
                    "let": "fragile",
                    "value": ["attempt": ["body": [["let": "broken", "value": ["fail": true]]], "rescue": ["body": []]]
                ]]
            ]
        ]

        // When / Then
        #expect {
            try loader.loadProcedure(fixture)
        } throws: { error in
            error is ValidationError && "\(error)".contains("attempt.rescue: must not be empty")
        }
    }

    @Test("a typo in a nested index reference is caught at load")
    func indexReferenceTypoRejected() {
        // Given
        let fixture: Value = [
            "parameters": [["name": "items", "type": "Array<Any>"]],
            "body": [["let": "pick", "value": ["ref": "items[${typoooo}]"]]]
        ]

        // When / Then. Nested index refs are part of the reference, not a blind
        // spot
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("an empty index segment is rejected at the load")
    func emptyIndexSegmentRejected() {
        // Given. `[]` is an author mistake, rejected at the load instead of being
        // carried into the model
        let fixture: Value = [
            "parameters": [["name": "items", "type": "Array<Any>"]],
            "body": [["let": "pick", "value": ["ref": "items[]"]]]
        ]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a name a run supplies is declared like every other name")
    func runValuesAreDeclared() throws {
        // Given. There is one way a name gets into a body. A value a run
        // supplies arrives as an argument and is written down as one.
        let declared: Value = [
            "parameters": [["name": "run", "type": "Dictionary<String, Any>"]],
            "body": [["let": "whoami", "value": ["ref": "run[\"id\"]"]]]
        ]
        let assumed: Value = ["body": [["let": "whoami", "value": ["ref": "run[\"id\"]"]]]]

        // When / Then
        #expect(throws: Never.self) {
            try loader.loadProcedure(declared)
        }
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(assumed)
        }
    }

    @Test("runtime data becomes IR through the loader's reading of a Value")
    func valueIsReadByTheLoader() throws {
        // Given. A step array that arrived as data (through a signature)
        // becomes IR through the loader's reading of a Value; the string stays
        // a literal even there
        let carried = Value.array([
            .dictionary(["let": .string("greet"), "value": .string("hello there")])
        ])

        // When
        let body = try loader.body(from: carried)

        // Then
        #expect(body.statements.count == 1)
        #expect(body.statements[0].binding == .constant("greet"))
        #expect(body.statements[0].expression.constantValue == .string("hello there"))
    }

    // MARK: - Public
    // MARK: - Private
}

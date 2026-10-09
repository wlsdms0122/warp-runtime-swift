//
//  OneSpellingTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/24/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// A document is read in the one spelling the writer writes for what it says,
// and a refusal says where it parts and what the one spelling writes there.
@Suite("A document is read in its one spelling")
struct OneSpellingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a key written with what its absence means is refused, naming nothing as the one spelling")
    func aDefaultWrittenOutIsRefused() {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["access": "internal", "result": 1]]
        ]

        // When / Then
        #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            let refusal = error as? ReadingError

            return refusal?.place?.rendered == "procedures.entry.access"
                && "\(error)".contains("The one way writes nothing")
        }
    }

    @Test("a list written out of its order is refused, naming what the one spelling writes there")
    func aListOutOfOrderIsRefused() {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": ["Standard.Text.text", "Standard.Logic.not"],
            "procedures": [
                "entry": [
                    "result": [
                        "call": [
                            "arguments": [["call": ["arguments": [true], "procedure": "Standard.Logic.not"]]],
                            "procedure": "Standard.Text.text"
                        ]
                    ]
                ]
            ]
        ]

        // When / Then
        #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            "\(error)".contains("imports[0]") && "\(error)".contains("The one way writes \"Standard.Logic.not\"")
        }
    }

    @Test("a named record under the record tag is the literal it writes, refused for its name")
    func aNamedRecordUnderTheTagIsRefused() throws {
        // Given
        let point = try Value.holding([(name: Name("x"), value: Value.int(1))], named: "Point")
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["result": ["record": point]]]
        ]

        // When / Then
        #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            error is ValidationError && "\(error)".contains("a literal writes a record's name")
        }
    }

    @Test("what a loader writes as canonical, the same loader reads back, whatever aliases it holds")
    func anAliasIsAReadingConvenience() throws {
        // Given. A table that reads `cond` as a conditional too
        let sut = Loader(registry: try ConstructRegistry.standard.registering(ConditionalForm.self, as: "cond"))
        let text: Value = [
            "procedures": [
                "entry": [
                    "parameters": [["name": "held", "type": "Bool"]],
                    "body": [["value": ["cond": ["when": ["ref": "held"], "then": []]]]]
                ]
            ]
        ]

        // When
        let document = try sut.canonical(text, from: .canonical)

        // Then
        #expect(throws: Never.self) { try sut.load(document, identity: nil) }
    }

    @Test("a document is read by the standard table, whatever aliases a loader holds")
    func aDocumentIsReadByTheStandardTable() throws {
        // Given. `cond` is this loader's reading convenience, and no document's
        let sut = Loader(registry: try ConstructRegistry.standard.registering(ConditionalForm.self, as: "cond"))
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": [
                "entry": [
                    "parameters": [["name": "held", "type": "Bool"]],
                    "body": [["value": ["cond": ["when": ["ref": "held"], "then": []]]]]
                ]
            ]
        ]

        // When / Then
        #expect(throws: ReadingError.self) { try sut.load(document, identity: nil) }
    }

    @Test("a record type nested in another keeps its own refusal and place")
    func aNestedRecordTypeKeepsItsRefusal() {
        // Given. The inner record type written bare, the way a document never
        // writes one
        let document: Value = [
            "warp": 1,
            "imports": [],
            "types": ["App.Outer": ["record": ["inner": ["id": "String"]]]],
            "procedures": ["entry": ["result": 1]]
        ]

        // When / Then
        #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            (error as? ReadingError)?.place?.rendered == "types.App.Outer.record.inner"
                && "\(error)".contains("A record type is written")
        }
    }

    @Test("a refusal inside a record or a cast is placed under the tag the text wrote", arguments: [
        (written: Value.dictionary(["record": .dictionary(["a": .dictionary(["ref": "missing"])])]), place: "procedures.entry.result.record.a"),
        (written: Value.dictionary(["as?": .dictionary(["of": .dictionary(["ref": "missing"]), "type": "Int"])]), place: "procedures.entry.result.as?.of")
    ])
    func aRefusalInsideATagIsPlacedUnderIt(written: Value, place: String) {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["result": written]]
        ]

        // When / Then
        #expect {
            try Loader().load(document, identity: nil)
        } throws: { error in
            (error as? any WarpError)?.place?.rendered == place
        }
    }

    // MARK: - Public
    // MARK: - Private
}

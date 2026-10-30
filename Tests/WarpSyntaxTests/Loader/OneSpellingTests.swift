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
    func aDefaultWrittenOutIsRefused() throws {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["access": "internal", "body": [["value": ["return": 1]]]]]
        ]

        let identity = try Identity.of(document)

        // When / Then
        #expect {
            try Loader().load(document)
        } throws: { error in
            let refusal = error as? ReadingError

            return refusal?.place?.rendered == "\(identity.short)/procedures.entry.access"
                && "\(error)".contains("The one way writes nothing")
        }
    }

    @Test("a parameter writing Any is refused, since writing no type says it")
    func aParameterWritingAnyIsRefused() {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["parameters": [["name": "x", "type": "Any"]], "body": [["value": ["return": 1]]]]]
        ]

        // When / Then
        #expect {
            try Loader().load(document)
        } throws: { error in
            "\(error)".contains("parameters[0].type") && "\(error)".contains("The one way writes nothing")
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
                    "body": [["value": ["return": [
                        "call": [
                            "arguments": [["call": ["arguments": [true], "procedure": "Standard.Logic.not"]]],
                            "procedure": "Standard.Text.text"
                        ]
                    ]]]]
                ]
            ]
        ]

        // When / Then
        #expect {
            try Loader().load(document)
        } throws: { error in
            "\(error)".contains("imports[0]") && "\(error)".contains("The one way writes \"Standard.Logic.not\"")
        }
    }

    @Test("a named struct under the struct tag is the literal it writes, refused for the struct it holds")
    func aNamedStructUnderTheTagIsRefused() throws {
        // Given
        let point = try Value.holding([(name: Name("x"), value: Value.int(1))], named: "Point")
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["value": ["return": ["struct": point]]]]]]
        ]

        // When / Then
        #expect {
            try Loader().load(document)
        } throws: { error in
            error is ValidationError && "\(error)".contains("a literal holds a struct")
        }
    }

    @Test("a field's type written as a mapping of fields keeps its own refusal and place")
    func aFieldTypeWrittenAsFieldsKeepsItsRefusal() throws {
        // Given. A field's type written as a mapping of fields, which is no
        // type form
        let document: Value = [
            "warp": 1,
            "imports": [],
            "types": ["App.Outer": ["struct": ["inner": ["id": "String"]]]],
            "procedures": ["entry": ["body": [["value": ["return": 1]]]]]
        ]

        let identity = try Identity.of(document)

        // When / Then
        #expect {
            try Loader().load(document)
        } throws: { error in
            (error as? ReadingError)?.place?.rendered == "\(identity.short)/types.App.Outer.struct.inner"
                && "\(error)".contains("A struct is declared under its name in `types` as `{ struct: { … } }`")
        }
    }

    @Test("a refusal inside a struct or a cast is placed under the tag the text wrote", arguments: [
        (
            written: Value.dictionary(["struct": .dictionary(["a": .dictionary(["ref": "missing"])])]),
            steps: ["procedures", "entry", "body", 0, "value", "return", "struct", "a"] as Value
        ),
        (
            written: Value.dictionary(["as?": .dictionary(["of": .dictionary(["ref": "missing"]), "type": "Int"])]),
            steps: ["procedures", "entry", "body", 0, "value", "return", "as?", "of"] as Value
        )
    ])
    func aRefusalInsideATagIsPlacedUnderIt(written: Value, steps: Value) throws {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["value": ["return": written]]]]]
        ]
        let identity = try Identity.of(document)

        // When / Then
        #expect {
            try Loader().load(document)
        } throws: { error in
            (error as? any WarpError)?.place?.value == [.bytes(identity.bytes), steps]
        }
    }

    // MARK: - Public
    // MARK: - Private
}

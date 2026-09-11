//
//  ConditionTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard

@Suite
struct ConditionTests {
    // MARK: - Property
    private let scope: [Name: Value] = ["kind": .string("a"), "n": .int(3), "none": .null, "gone": .null]

    // MARK: - Initializer
    // MARK: - Test
    @Test("predicates evaluate against scope values")
    func predicatesEvaluateAgainstScope() throws {
        // Given
        let sut = Folding(bindings: scope, natives: Module.standard)

        // Then
        #expect(try sut.evaluate(
            equals(.reference(path("kind")), .literal(.string("a")))
        ))
        #expect(try sut.evaluate(
            differs(.reference(path("kind")), .literal(.string("b")))
        ))
        #expect(try sut.evaluate(
            .call(Call(receiver: .array([.literal(.int(3)), .literal(.int(4))]), selector: "std.collection.contains", arguments: ["value": .reference(path("n"))]))
        ))
        #expect(try sut.evaluate(
            differs(.reference(path("n")), .literal(.null))
        ))
        #expect(try !sut.evaluate(
            differs(.reference(path("none")), .literal(.null))
        ))
        #expect(try !sut.evaluate(
            differs(.reference(path("gone")), .literal(.null))
        ))
    }

    @Test("both sides of a predicate are expressions")
    func bothSidesAreExpressions() throws {
        // Given
        let sut = Folding(bindings: [
            "left": .string("same"),
            "right": .string("same"),
            "candidates": .array([.string("same"), .string("other")])
        ], natives: Module.standard)

        // Then. A reference compares against another reference
        #expect(try sut.evaluate(
            equals(.reference(path("left")), .reference(path("right")))
        ))

        // And one_of can draw its candidates from the scope
        #expect(try sut.evaluate(
            .call(Call(receiver: .reference(path("candidates")), selector: "std.collection.contains", arguments: ["value": .reference(path("left"))]))
        ))
    }

    @Test("numeric equality crosses int and double")
    func numericEqualityCrossesIntAndDouble() throws {
        // Given
        let sut = Folding(bindings: scope, natives: Module.standard)

        // Then
        #expect(try sut.evaluate(
            equals(.reference(path("n")), .literal(.double(3.0)))
        ))
    }

    @Test("combinators compose nested conditions")
    func combinatorsCompose() throws {
        // Given
        let sut = Folding(bindings: scope, natives: Module.standard)
        let condition = every(
            equals(.reference(path("kind")), .literal(.string("a"))),
            negating(equals(.reference(path("n")), .literal(.int(4))))
            )

        // Then
        #expect(try sut.evaluate(condition))
    }

    @Test("text atoms evaluate on strings; asking a number is unfit")
    func textAtomsEvaluateOnStrings() throws {
        // Given
        let sut = Folding(bindings: [
            "title": .string("hello, spec"),
            "tags": .array([.string("a"), .string("b")]),
            "n": .int(3),
            "gone": .null
        ], natives: Module.standard)

        // Then
        #expect(try sut.evaluate(
            .call(Call(receiver: .reference(path("title")), selector: "std.collection.contains", arguments: ["value": .literal(.string("spec"))]))
        ))
        #expect(try sut.evaluate(
            .call(Call(receiver: .reference(path("tags")), selector: "std.collection.contains", arguments: ["value": .literal(.string("b"))]))
        ))
        #expect(try sut.evaluate(
            .call(Call(receiver: .reference(path("title")), selector: "std.text.startsWith", arguments: ["value": .literal(.string("hello"))]))
        ))
        #expect(try sut.evaluate(
            .call(Call(receiver: .reference(path("title")), selector: "std.text.regex", arguments: ["value": .literal(.string("sp.c$"))]))
        ))
        #expect(try !sut.evaluate(
            .call(Call(receiver: .reference(path("gone")), selector: "std.collection.contains", arguments: ["value": .literal(.string("x"))]))
        ))

        // A text atom asking a number is shape misuse, not a false answer
        #expect(throws: ReferenceUnfit.self) {
            try sut.evaluate(
                .call(Call(receiver: .reference(path("n")), selector: "std.text.startsWith", arguments: ["value": .literal(.string("3"))]))
            )
        }
    }

    @Test("an invalid regex pattern is rejected at link")
    func invalidRegexRejectedAtLink() {
        // Given
        let fixture: Value = [
            "parameters": ["title": "string"],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "title"], "regex": "[unclosed"],
                        "then": [["let": "taken", "value": "x"]]
                    ]
                ]]
            ]
        ]

        // When / Then. The pattern compiles before any run. Checking it while
        // decoding would make the notation hold the vocabulary; it is checked
        // where names resolve.
        #expect(throws: BuildError.self) {
            try Builder().build(
                [try Loader.testing.loadProcedure(fixture, importing: ["regex"])] + Module.standard,
                entry: entryName
            )
        }
    }

    @Test("shape misuse in a condition is unfit, not false")
    func conditionShapeMisuseThrowsUnfit() throws {
        // Given
        let sut = Folding(bindings: scope, natives: Module.standard)

        // When / Then. A typo'd drill must not silently read as false
        #expect(throws: ReferenceUnfit.self) {
            try sut.evaluate(
                differs(.reference(path("n.field")), .literal(.null))
            )
        }
    }

    @Test("two operator keys in one condition are rejected")
    func doubleOperatorKeysRejected() {
        // Given
        let fixture: Value = [
            "parameters": ["k": "string"],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "k"], "equal": "a", "notEqual": "b"],
                        "then": [["let": "taken", "value": "x"]]
                    ]
                ]]
            ]
        ]

        // When / Then. First-wins would silently drop the second predicate
        #expect(throws: ReadingError.self) {
            try Loader.testing.loadProcedure(fixture)
        }
    }

    @Test("validation covers both sides of a predicate")
    func validationCoversBothSides() {
        // Given
        let condition = equals(
            .reference(path("left")),
            .reference(path("outer.right"))
            )

        // Then. Neither side is skipped
        #expect(validates(condition, visible: ["left", "outer"]))
        #expect(!validates(condition, visible: ["left"]))
        #expect(!validates(condition, visible: ["outer"]))
    }
}

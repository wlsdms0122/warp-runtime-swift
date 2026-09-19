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
    func predicatesEvaluateAgainstScope() async throws {
        // Given
        let sut = try await folding(scope)

        // Then
        #expect(try await sut.evaluate(
            equals(.reference(path("kind")), .literal(.string("a")))
        ))
        #expect(try await sut.evaluate(
            differs(.reference(path("kind")), .literal(.string("b")))
        ))
        #expect(try await sut.evaluate(
            .call(Call(receiver: .array([.literal(.int(3)), .literal(.int(4))]), selector: "std.collection.contains", arguments: ["value": .reference(path("n"))]))
        ))
        #expect(try await sut.evaluate(
            differs(.reference(path("n")), .literal(.null))
        ))
        #expect(try await !sut.evaluate(
            differs(.reference(path("none")), .literal(.null))
        ))
        #expect(try await !sut.evaluate(
            differs(.reference(path("gone")), .literal(.null))
        ))
    }

    @Test("both sides of a predicate are expressions")
    func bothSidesAreExpressions() async throws {
        // Given
        let sut = try await folding([
            "left": .string("same"),
            "right": .string("same"),
            "candidates": .array([.string("same"), .string("other")])
        ])

        // Then. A reference compares against another reference
        #expect(try await sut.evaluate(
            equals(.reference(path("left")), .reference(path("right")))
        ))

        // And one_of can draw its candidates from the scope
        #expect(try await sut.evaluate(
            .call(Call(receiver: .reference(path("candidates")), selector: "std.collection.contains", arguments: ["value": .reference(path("left"))]))
        ))
    }

    @Test("numeric equality crosses int and double")
    func numericEqualityCrossesIntAndDouble() async throws {
        // Given
        let sut = try await folding(scope)

        // Then
        #expect(try await sut.evaluate(
            equals(.reference(path("n")), .literal(.double(3.0)))
        ))
    }

    @Test("combinators compose nested conditions")
    func combinatorsCompose() async throws {
        // Given
        let sut = try await folding(scope)
        let condition = every(
            equals(.reference(path("kind")), .literal(.string("a"))),
            negating(equals(.reference(path("n")), .literal(.int(4))))
            )

        // Then
        #expect(try await sut.evaluate(condition))
    }

    @Test("text atoms evaluate on strings; asking a number is unfit")
    func textAtomsEvaluateOnStrings() async throws {
        // Given
        let sut = try await folding([
            "title": .string("hello, spec"),
            "tags": .array([.string("a"), .string("b")]),
            "n": .int(3),
            "gone": .null
        ])

        // Then
        #expect(try await sut.evaluate(
            .call(Call(receiver: .reference(path("title")), selector: "std.text.contains", arguments: ["value": .literal(.string("spec"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(receiver: .reference(path("tags")), selector: "std.collection.contains", arguments: ["value": .literal(.string("b"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(receiver: .reference(path("title")), selector: "std.text.startsWith", arguments: ["value": .literal(.string("hello"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(receiver: .reference(path("title")), selector: "std.text.regex", arguments: ["value": .literal(.string("sp.c$"))]))
        ))
        // Absence is not an empty collection. `contains` walks what it was
        // handed, the way every other collection procedure does, so asking it
        // of nothing is refused rather than answered false.
        await #expect(throws: (any Error).self) {
            try await sut.evaluate(
                .call(Call(receiver: .reference(path("gone")), selector: "std.collection.contains", arguments: ["value": .literal(.string("x"))]))
            )
        }

        // A text atom asking a number is type misuse, not a false answer
        await #expect(throws: ReferenceUnfit.self) {
            try await sut.evaluate(
                .call(Call(receiver: .reference(path("n")), selector: "std.text.startsWith", arguments: ["value": .literal(.string("3"))]))
            )
        }
    }

    @Test("an invalid regex pattern is rejected at link")
    func invalidRegexRejectedAtLink() async {
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
        await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Loader.testing.loadProcedure(fixture, importing: ["regex"])] + Module.standard + Module.regex,
                entry: entryName
            )
        }
    }

    @Test("type misuse in a condition is unfit, not false")
    func conditionTypeMisuseThrowsUnfit() async throws {
        // Given
        let sut = try await folding(scope)

        // When / Then. A typo'd drill must not silently read as false
        await #expect(throws: ReferenceUnfit.self) {
            try await sut.evaluate(
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

    // MARK: - Private
    // A fold against the standard vocabulary as a caller gets it: built, so
    // the procedures written in Warp answer here the way the native ones do.
    private func folding(_ bindings: [Name: Value]) async throws -> Folding {
        Folding(
            bindings: bindings,
            in: try await Builder().build(
                [try Module(procedures: [entryName: Procedure(body: [], result: .literal(.null))])]
                    + Module.standard + Module.regex,
                entry: entryName
            )
        )
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

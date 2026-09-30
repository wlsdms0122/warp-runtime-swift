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
            .call(Call(selector: "std.collection.contains", arguments: [.array([.literal(.int(3)), .literal(.int(4))]), .reference(path("n"))]))
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
            .call(Call(selector: "std.collection.contains", arguments: [.reference(path("candidates")), .reference(path("left"))]))
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

    @Test("text atoms evaluate on strings; asking a number is refused")
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
            .call(Call(selector: "std.text.contains", arguments: [.reference(path("title")), .literal(.string("spec"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(selector: "std.collection.contains", arguments: [.reference(path("tags")), .literal(.string("b"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(selector: "std.text.startsWith", arguments: [.reference(path("title")), .literal(.string("hello"))]))
        ))
        // Absence is not an empty collection. `contains` walks what it was
        // handed, the way every other collection procedure does, so asking it
        // of nothing is refused rather than answered false.
        await #expect(throws: (any Error).self) {
            try await sut.evaluate(
                .call(Call(selector: "std.collection.contains", arguments: [.reference(path("gone")), .literal(.string("x"))]))
            )
        }

        // A text atom asking a number is type misuse, not a false answer. The
        // number is refused where the argument it stands at is settled
        await #expect(throws: ArgumentError.self) {
            try await sut.evaluate(
                .call(Call(selector: "std.text.startsWith", arguments: [.reference(path("n")), .literal(.string("3"))]))
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
            "parameters": [["name": "k", "type": "string"]],
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

    // MARK: - Public
    // MARK: - Private
    // A fold against the standard vocabulary as a caller gets it: built, so
    // the procedures written in Warp answer here the way the native ones do.
    private func folding(_ bindings: [Name: Value]) async throws -> Folding {
        Folding(
            bindings: bindings,
            in: try await Builder().build(
                [try Module(procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))])]
                    + Module.standard
            )
        )
    }
}

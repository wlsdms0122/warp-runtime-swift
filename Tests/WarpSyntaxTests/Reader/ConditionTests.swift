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
import WarpTestSupport

@Suite("A condition a document writes")
struct ConditionTests {
    // A condition read by a run against the standard vocabulary as a host
    // gets it, so the procedures written in Warp answer here the way the
    // native ones do. The bindings are handed over as arguments, each
    // declared as the type of the value it binds.
    private struct Scope {
        // MARK: - Property
        let bindings: [Name: Value]

        // MARK: - Initializer
        init(_ bindings: [Name: Value]) {
            self.bindings = bindings
        }

        // MARK: - Public
        func evaluate(_ condition: Warp.Expression) async throws -> Bool {
            let image = try await Builder().build(
                [
                    try Module(procedures: [
                        entryName: Procedure(
                            access: .public,
                            signature: Signature(
                                parameters: bindings.keys.sorted().map { name in
                                    Parameter(name: name, type: declared(bindings[name] ?? .null))
                                }
                            ),
                            body: [],
                            result: condition
                        )
                    ])
                ] + Module.standard
            )

            guard case let .bool(answer) = try await Executor().run(image, arguments: bindings) else {
                throw ReadingError("a condition must answer Bool")
            }

            return answer
        }

        // MARK: - Private
        private func declared(_ value: Value) -> TypeExpression {
            let table = TypeTable.empty.loweredTypes

            return LoweredType(of: value, in: table).spelled(in: table) ?? .any
        }
    }

    // MARK: - Property
    private let scope: [Name: Value] = ["kind": .string("a"), "n": .int(3), "none": .null, "gone": .null]

    // MARK: - Initializer
    // MARK: - Test
    @Test("predicates evaluate against scope values")
    func predicatesEvaluateAgainstScope() async throws {
        // Given
        let sut = Scope(scope)

        // When / Then
        #expect(try await sut.evaluate(
            equals(.reference(path("kind")), .literal(.string("a")))
        ))
        #expect(try await sut.evaluate(
            differs(.reference(path("kind")), .literal(.string("b")))
        ))
        #expect(try await sut.evaluate(
            .call(Call(selector: "Standard.Collection.contains", arguments: [.array([.literal(.int(3)), .literal(.int(4))]), .reference(path("n"))]))
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
        let sut = Scope([
            "left": .string("same"),
            "right": .string("same"),
            "candidates": .array([.string("same"), .string("other")])
        ])

        // When / Then. A reference compares against another reference
        #expect(try await sut.evaluate(
            equals(.reference(path("left")), .reference(path("right")))
        ))

        // And one_of can draw its candidates from the scope
        #expect(try await sut.evaluate(
            .call(Call(selector: "Standard.Collection.contains", arguments: [.reference(path("candidates")), .reference(path("left"))]))
        ))
    }

    @Test("numeric equality crosses Int and Double")
    func numericEqualityCrossesIntAndDouble() async throws {
        // Given
        let sut = Scope(scope)

        // When / Then
        #expect(try await sut.evaluate(
            equals(.reference(path("n")), .literal(.double(3.0)))
        ))
    }

    @Test("combinators compose nested conditions")
    func combinatorsCompose() async throws {
        // Given
        let sut = Scope(scope)
        let condition = every(
            equals(.reference(path("kind")), .literal(.string("a"))),
            negating(equals(.reference(path("n")), .literal(.int(4))))
            )

        // When / Then
        #expect(try await sut.evaluate(condition))
    }

    @Test("text atoms evaluate on strings; asking a number is refused")
    func textAtomsEvaluateOnStrings() async throws {
        // Given
        let sut = Scope([
            "title": .string("hello, spec"),
            "tags": .array([.string("a"), .string("b")]),
            "n": .int(3),
            "gone": .null
        ])

        // When / Then
        #expect(try await sut.evaluate(
            .call(Call(selector: "Standard.Text.contains", arguments: [.reference(path("title")), .literal(.string("spec"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(selector: "Standard.Collection.contains", arguments: [.reference(path("tags")), .literal(.string("b"))]))
        ))
        #expect(try await sut.evaluate(
            .call(Call(selector: "Standard.Text.startsWith", arguments: [.reference(path("title")), .literal(.string("hello"))]))
        ))

        // And. Absence is not an empty collection. `contains` walks what it was
        // handed, the way every other collection procedure does, so asking it
        // of nothing is refused rather than answered false.
        await #expect(throws: (any Error).self) {
            try await sut.evaluate(
                .call(Call(selector: "Standard.Collection.contains", arguments: [.reference(path("gone")), .literal(.string("x"))]))
            )
        }

        // And. A text atom asking a number is type misuse, not a false answer.
        // The number is refused at the build, where the argument it stands at
        // is judged
        await #expect(throws: BuildError.self) {
            try await sut.evaluate(
                .call(Call(selector: "Standard.Text.startsWith", arguments: [.reference(path("n")), .literal(.string("3"))]))
            )
        }
    }

    @Test("type misuse in a condition is refused, not false")
    func conditionTypeMisuseIsRefused() async throws {
        // Given
        let sut = Scope(scope)

        // When / Then. A typo'd drill must not silently read as false
        await #expect(throws: BuildError.self) {
            try await sut.evaluate(
                differs(.reference(path("n.field")), .literal(.null))
            )
        }
    }

    @Test("two operator keys in one condition are rejected")
    func doubleOperatorKeysRejected() {
        // Given
        let fixture: Value = [
            "parameters": [["name": "k", "type": "String"]],
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

        // When / Then. Neither side is skipped
        #expect(validates(condition, visible: ["left", "outer"]))
        #expect(!validates(condition, visible: ["left"]))
        #expect(!validates(condition, visible: ["outer"]))
    }

    // MARK: - Public
    // MARK: - Private
}

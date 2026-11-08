//
//  ExpressionTypeTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard
import WarpTestSupport

// What the build judged the expression at a place to hold, asked by the
// place's value.
@Suite("The type of the expression at a place")
struct ExpressionTypeTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a statement's expression reads as its type, with the fields a dot reads on it")
    func aStatementReadsAsItsType() async throws {
        // Given
        let document = Self.document(body: [
            ["value": ["ref": "report"]]
        ])
        let sut = Builder()

        // When
        let answer = try await sut.expressionType(
            at: Self.place(in: document, ["procedures", "entry", "body", 0, "value"]),
            of: [try loader.load(document)],
            against: Self.laid()
        )

        // Then
        #expect(answer?.type == "Report")
        #expect(answer?.fields == [
            ExpressionType.Field(name: "count", type: "Int"),
            ExpressionType.Field(name: "title", type: "String?")
        ])
    }

    @Test("an Optional reads as itself, with the fields of the struct it holds")
    func anOptionalReadsThroughToItsFields() async throws {
        // Given
        let document = Self.document(body: [
            ["value": ["ref": "maybe"]]
        ])
        let sut = Builder()

        // When
        let answer = try await sut.expressionType(
            at: Self.place(in: document, ["procedures", "entry", "body", 0, "value"]),
            of: [try loader.load(document)],
            against: Self.laid()
        )

        // Then
        #expect(answer?.type == "Report?")
        #expect(answer?.fields.map(\.name) == ["count", "title"])
    }

    @Test("a construct's condition reads as its type, with the names before it")
    func aConditionReadsAsItsType() async throws {
        // Given
        let document = Self.document(body: [
            ["let": "done", "value": true],
            ["value": ["loop": ["while": ["ref": "done"], "body": []]]]
        ])
        let sut = Builder()

        // When
        let answer = try await sut.expressionType(
            at: Self.place(in: document, ["procedures", "entry", "body", 1, "value", "loop", "while"]),
            of: [try loader.load(document)],
            against: Self.laid()
        )

        // Then
        #expect(answer?.type == "Bool")
        #expect(answer?.fields == [])
    }

    @Test("a whole number written where a Double is declared reads as a Double")
    func aWholeNumberWhereADoubleIsDeclaredReadsAsOne() async throws {
        // Given
        let document: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["returns": "Double", "body": [["value": ["return": 1]]]]]
        ]
        let sut = Builder()

        // When
        let answer = try await sut.expressionType(
            at: Self.place(in: document, ["procedures", "entry", "body", 0, "value", "return"]),
            of: [try loader.load(document)],
            against: Self.laid()
        )

        // Then
        #expect(answer?.type == "Double")
    }

    @Test("what the build refuses after the expression leaves the answer standing")
    func aRefusalAfterLeavesTheAnswer() async throws {
        // Given. Another body sends what nothing declares
        let document = Self.document(
            body: [["value": ["ref": "report"]]],
            other: [["value": ["call": ["procedure": "missing"]]]],
            imports: ["missing"]
        )
        let sut = Builder()

        // When
        let answer = try await sut.expressionType(
            at: Self.place(in: document, ["procedures", "entry", "body", 0, "value"]),
            of: [try loader.load(document)],
            against: Self.laid()
        )

        // Then
        #expect(answer?.type == "Report")
    }

    @Test("what the build refuses before the expression refuses the question")
    func aRefusalBeforeRefusesTheQuestion() async throws {
        // Given. The statement before it sends what nothing declares
        let document = Self.document(
            body: [
                ["value": ["call": ["procedure": "missing"]]],
                ["value": ["ref": "report"]]
            ],
            imports: ["missing"]
        )
        let sut = Builder()
        let module = try loader.load(document)
        let laid = try await Self.laid()

        // When
        let error = await expectRefusal {
            try await sut.expressionType(
                at: Self.place(in: document, ["procedures", "entry", "body", 1, "value"]),
                of: [module],
                against: laid
            )
        }

        // Then
        #expect(error?.message == "sends 'missing', which neither this document nor one it stands on declares")
    }

    @Test("a place holding no expression the build judged has no answer")
    func aPlaceHoldingNoExpressionHasNone() async throws {
        // Given
        let document = Self.document(body: [
            ["value": ["ref": "report"]]
        ])
        let sut = Builder()

        // When
        let answer = try await sut.expressionType(
            at: Self.place(in: document, ["procedures", "entry", "parameters", 0]),
            of: [try loader.load(document)],
            against: Self.laid()
        )

        // Then
        #expect(answer == nil)
    }

    // MARK: - Public
    // MARK: - Private
    // A document declaring `Report` and an entry taking one and an Optional
    // of one with `body`, beside another procedure with `other` where there
    // is one. Either may send what nothing declares, which `imports` lists.
    private static func document(body: Value, other: Value? = nil, imports: Value = []) -> Value {
        let entry: Value = [
            "parameters": [
                ["name": "report", "type": "Report"],
                ["name": "maybe", "type": "Report?"]
            ],
            "body": body
        ]

        return [
            "warp": 1,
            "imports": imports,
            "types": ["Report": ["struct": ["count": "Int", "title": "String?"]]],
            "procedures": other.map { other in ["entry": entry, "other": ["body": other]] } ?? ["entry": entry]
        ]
    }

    // The value WARP-65 names a place of `document` by.
    private static func place(in document: Value, _ steps: Value) throws -> Value {
        [.bytes(try Identity.of(document).bytes), steps]
    }

    private static func laid() async throws -> Laid {
        let builder = Builder()
        let supplying = try Supplying(Module.standard)

        return try builder.lay(try await builder.compile(Module.standard), supplying: supplying)
    }
}

//
//  FieldPlaceTests.swift
//  WarpTests
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Testing
@testable import Warp

// Where a path's field is found. The link lays out every record it proved, so
// a field of one is lowered to the place it stands in and the run reads that
// place. What the link did not lay out is read by name, and the two answer the
// same thing.
@Suite("A field the link laid out is read by its place")
struct FieldPlaceTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a declared record's field is lowered to its place")
    func aDeclaredFieldIsLoweredToItsPlace() throws {
        // Given. The parameter says what it holds, so the link lays it out and
        // the position is the layout's.
        let sut = try Procedure(
            signature: Signature(
                parameters: ["point": Parameter(type: .record(["x": .int, "y": .int]))]
            ),
            body: [],
            result: .reference([.key("point"), .key("y")])
        )

        // When
        let steps = try resultSteps(of: sut)

        // Then. `y` follows `x` in the layout's order.
        #expect(steps == [.field(1, "y", optional: false)])
    }

    @Test("a field of a record literal is lowered to its place")
    func aLiteralFieldIsLoweredToItsPlace() throws {
        // Given. Nothing was declared, and the link still laid the literal out
        let sut = Procedure(
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .record(["b": .literal(.int(2)), "a": .literal(.int(1))])
                )
            ],
            result: .reference([.key("held"), .key("b")])
        )

        // When
        let steps = try resultSteps(of: sut)

        // Then
        #expect(steps == [.field(1, "b", optional: false)])
    }

    @Test("a dictionary's keys are the value's, so they are read by name")
    func aDictionaryIsReadByName() throws {
        // Given
        let sut = try Procedure(
            signature: Signature(
                parameters: ["entries": Parameter(type: .dictionary(.int))]
            ),
            body: [],
            result: .reference([.key("entries"), .key("a")])
        )

        // When
        let steps = try resultSteps(of: sut)

        // Then
        #expect(steps == [.key("a", optional: false)])
    }

    @Test("a place is read at every depth the link laid out")
    func nestedFieldsAreLoweredToTheirPlaces() throws {
        // Given
        let sut = try Procedure(
            signature: Signature(
                parameters: [
                    "outer": Parameter(type: .record([
                        "head": .int,
                        "inner": .record(["deep": .string, "beside": .int])
                    ]))
                ]
            ),
            body: [],
            result: .reference([.key("outer"), .key("inner"), .key("deep")])
        )

        // When
        let steps = try resultSteps(of: sut)

        // Then. `inner` follows `head`, and `deep` follows `beside`
        #expect(steps == [.field(1, "inner", optional: false), .field(1, "deep", optional: false)])
    }

    @Test("a named type is followed to the record it stands for")
    func aNamedRecordIsLoweredToItsPlace() throws {
        // Given
        let module = try Module(
            types: ["Point": .record(["x": .int, "y": .int])],
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["point": Parameter(type: .named("Point"))]),
                    body: [],
            result: .reference([.key("point"), .key("y")])
                )
            ]
        )

        // When
        let image = try linker.link([module] + Module.standard, entry: entryName)

        // Then
        #expect(try steps(of: image) == [.field(1, "y", optional: false)])
    }

    @Test("a value carrying more than the slot declares is read at the slot's places")
    func aWiderValueSettlesToTheDeclaredLayout() async throws {
        // Given. The argument holds a field the slot does not declare. Settling
        // builds it on the slot's layout, so the place the link lowered is the
        // place the field stands in.
        let sut = try Procedure(
            signature: Signature(
                parameters: ["point": Parameter(type: .record(["x": .int, "y": .int]))]
            ),
            body: [],
            result: .reference([.key("point"), .key("y")])
        )

        // When
        let answer = try await run(
            sut,
            arguments: [
                "point": .record(Record(name: nil, ["a": .int(0), "x": .int(1), "y": .int(2), "z": .int(3)]))
            ]
        )

        // Then
        #expect(answer == .int(2))
    }

    @Test("a box is read by name, since a write puts in what it was handed")
    func aBoxIsReadByName() async throws {
        // Given. A write lands as it was handed, so what a box holds after one
        // is laid out by the value and not by the declaration. The written
        // record carries a field that stands before the declared ones.
        let sut = Procedure(
            signature: Signature(parameters: ["given": Parameter(type: .any)]),
            body: [
                Statement(
                    binding: .variable("point", declared: .record(["x": .int, "y": .int])),
                    expression: .record(["x": .literal(.int(1)), "y": .literal(.int(2))])
                ),
                Statement(
                    binding: .assignment([PathSegment.key("point")]),
                    expression: .reference([.key("given")])
                )
            ],
            result: .reference([.key("point"), .key("y")])
        )

        // When
        let steps = try resultSteps(of: sut)
        let answer = try await run(
            sut,
            arguments: [
                "given": .record(Record(name: nil, ["a": .int(0), "x": .int(1), "y": .int(2)]))
            ]
        )

        // Then
        #expect(steps == [.key("y", optional: false)])
        #expect(answer == .int(2))
    }

    @Test("a place and a name answer the same field")
    func bothWaysAnswerTheSameField() async throws {
        // Given. One reads a shape the link laid out and one a dictionary,
        // whose keys are the value's
        let laid = try Procedure(
            signature: Signature(
                parameters: ["point": Parameter(type: .record(["x": .int, "y": .int]))]
            ),
            body: [],
            result: .reference([.key("point"), .key("y")])
        )
        let named = try Procedure(
            signature: Signature(parameters: ["point": Parameter(type: .dictionary(.int))]),
            body: [],
            result: .reference([.key("point"), .key("y")])
        )
        let argument: [Name: Value] = ["point": .record(Record(name: nil, ["x": .int(1), "y": .int(2)]))]

        // When
        let byPlace = try await run(laid, arguments: argument)
        let byName = try await run(named, arguments: argument)

        // Then
        #expect(byPlace == .int(2))
        #expect(byPlace == byName)
    }

    // MARK: - Private
    // The steps of the path a body answers with, which is where these tests
    // read what the link lowered.
    private func resultSteps(of procedure: Procedure) throws -> [Step] {
        let image = try linker.link(
            [try Module(procedures: [entryName: procedure])] + Module.standard,
            entry: entryName
        )

        return try steps(of: image)
    }

    private func steps(of image: Image) throws -> [Step] {
        guard
            case let .body(body, _) = image.entry.implementation,
            case let .local(_, steps)? = body.result
        else {
            Issue.record("the entry does not answer with a path")

            return []
        }

        return steps
    }
}

extension Step: Equatable {
    public static func == (lhs: Step, rhs: Step) -> Bool {
        switch (lhs, rhs) {
        case let (.field(mine, myName, myMark), .field(theirs, theirName, theirMark)):
            return mine == theirs && myName == theirName && myMark == theirMark

        case let (.key(mine, myMark), .key(theirs, theirMark)):
            return mine == theirs && myMark == theirMark

        case let (.index(mine, myMark), .index(theirs, theirMark)):
            return mine == theirs && myMark == theirMark

        case let (.at(mine, myInner, myMark), .at(theirs, theirInner, theirMark)):
            return mine == theirs && myInner == theirInner && myMark == theirMark

        case let (.word(mine, myName, myMark), .word(theirs, theirName, theirMark)):
            return mine == theirs && myName == theirName && myMark == theirMark

        default:
            return false
        }
    }
}

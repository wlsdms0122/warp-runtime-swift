//
//  FieldPlaceTests.swift
//  WarpTests
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// Where a path's field is found. The build lays out every record it proved, so
// a field of one is lowered to the place it stands in and the run reads that
// place. What the build did not lay out is read by name, and the two answer the
// same thing.
@Suite("A field the build laid out is read by its place")
struct FieldPlaceTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a declared record's field is lowered to its place")
    func aDeclaredFieldIsLoweredToItsPlace() async throws {
        // Given. The parameter says what it holds, so the build lays it out and
        // the position is the layout's.
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "point", type: .record(["x": .int, "y": .int]))]
            ),
            body: [],
            result: .reference([.key("point"), .key("y")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then. `y` follows `x` in the layout's order.
        #expect(steps == [.field(1, "y", optional: false)])
    }

    @Test("a field of a record literal is lowered to its place")
    func aLiteralFieldIsLoweredToItsPlace() async throws {
        // Given. Nothing was declared, and the build still laid the literal out
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
        let steps = try await resultSteps(of: sut)

        // Then
        #expect(steps == [.field(1, "b", optional: false)])
    }

    @Test("a dictionary's keys are the value's, so they are read by name")
    func aDictionaryIsReadByName() async throws {
        // Given
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "entries", type: .dictionary(.int))]
            ),
            body: [],
            result: .reference([.key("entries"), .key("a")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then
        #expect(steps == [.key("a", optional: false)])
    }

    @Test("a place is read at every depth the build laid out")
    func nestedFieldsAreLoweredToTheirPlaces() async throws {
        // Given
        let sut = Procedure(
            signature: Signature(
                parameters: [
                    Parameter(name: "outer", type: .record([
                        "head": .int,
                        "inner": .record(["deep": .string, "beside": .int])
                    ]))
                ]
            ),
            body: [],
            result: .reference([.key("outer"), .key("inner"), .key("deep")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then. `inner` follows `head`, and `deep` follows `beside`
        #expect(steps == [.field(1, "inner", optional: false), .field(1, "deep", optional: false)])
    }

    @Test("a named type is followed to the record it stands for")
    func aNamedRecordIsLoweredToItsPlace() async throws {
        // Given
        let module = try Module(
            types: ["Point": .record(["x": .int, "y": .int])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "point", type: .named("Point"))]),
                    body: [],
                    result: .reference([.key("point"), .key("y")])
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try steps(of: image) == [.field(1, "y", optional: false)])
    }

    @Test("a value carrying more than the slot declares is read at the slot's places")
    func aWiderValueSettlesToTheDeclaredLayout() async throws {
        // Given. The argument holds a field the slot does not declare. Settling
        // builds it on the slot's layout, so the place the build lowered is the
        // place the field stands in.
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "point", type: .record(["x": .int, "y": .int]))]
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

    @Test("a box that said what it holds is read by its place")
    func aDeclaredBoxIsReadByItsPlace() async throws {
        // Given. The written record carries a field that stands before the
        // declared ones, so a place read off the value's own layout would
        // land on the wrong field. A write settles to what the box said it
        // holds, so the value is laid out the way the declaration says.
        let sut = Procedure(
            signature: Signature(parameters: [Parameter(name: "given", type: .any)]),
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
        let steps = try await resultSteps(of: sut)
        let answer = try await run(
            sut,
            arguments: [
                "given": .record(Record(name: nil, ["a": .int(0), "x": .int(1), "y": .int(2)]))
            ]
        )

        // Then
        #expect(steps == [.field(1, "y", optional: false)])
        #expect(answer == .int(2))
    }

    @Test("a write to a box that said nothing stands as it was handed")
    func anUndeclaredBoxTakesWhatItWasHanded() async throws {
        // Given. Nothing was declared, so there is nothing for a write to
        // settle to and nothing the build laid out
        let sut = Procedure(
            signature: Signature(parameters: [Parameter(name: "given", type: .dictionary(.int))]),
            body: [
                Statement(binding: .variable("held"), expression: .record(["y": .literal(.int(0))])),
                Statement(
                    binding: .assignment([PathSegment.key("held")]),
                    expression: .reference([.key("given")])
                )
            ],
            result: .reference([.key("held"), .key("y")])
        )

        // When
        let steps = try await resultSteps(of: sut)
        let answer = try await run(
            sut,
            arguments: ["given": .record(Record(name: nil, ["a": .int(0), "y": .int(2)]))]
        )

        // Then
        #expect(steps == [.key("y", optional: false)])
        #expect(answer == .int(2))
    }

    @Test("a box takes the layout it declared, so a write drops what it does not name")
    func aWriteSettlesToTheDeclaredLayout() async throws {
        // Given. The declaration is the whole of what the box holds, the way
        // it is for a parameter and for a name bound once
        let sut = Procedure(
            signature: Signature(parameters: [Parameter(name: "given", type: .any)]),
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
            result: .reference([.key("point")])
        )

        // When
        let answer = try await run(
            sut,
            arguments: [
                "given": .record(Record(name: nil, ["a": .int(0), "x": .int(1), "y": .int(2)]))
            ]
        )

        // Then
        #expect(answer == .record(Record(name: nil, ["x": .int(1), "y": .int(2)])))
    }

    @Test("a place and a name answer the same field")
    func bothWaysAnswerTheSameField() async throws {
        // Given. One reads a type the build laid out and one a dictionary,
        // whose keys are the value's
        let laid = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "point", type: .record(["x": .int, "y": .int]))]
            ),
            body: [],
            result: .reference([.key("point"), .key("y")])
        )
        let named = Procedure(
            signature: Signature(parameters: [Parameter(name: "point", type: .dictionary(.int))]),
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

    // MARK: - Public
    // MARK: - Private
    // The steps of the path a body answers with, which is where these tests
    // read what the build lowered.
    private func resultSteps(of procedure: Procedure) async throws -> [Step] {
        let image = try await builder.build(
            [try Module(procedures: [entryName: procedure.with(access: .public)])] + Module.standard
        )

        return try steps(of: image)
    }

    private func steps(of image: Image) throws -> [Step] {
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            case let .local(address)? = body.result
        else {
            Issue.record("the entry does not answer with a path")

            return []
        }

        return address.steps
    }
}

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

// Where a path's field is found. The build lays out every struct it proved, so
// a field of one is lowered to the place it stands in and the run reads that
// place. What the build did not lay out is read by name, and the two answer the
// same thing.
@Suite("A field the build laid out is read by its place")
struct FieldPlaceTests {
    // MARK: - Property
    private let builder = Builder()

    // The structs these tests read fields of.
    private static let types: [Name: TypeDeclaration] = [
        "App.Point": .struct(["x": .int, "y": .int]),
        "App.Pair": .struct(["a": .int, "b": .int]),
        "App.Outer": .struct(["head": .int, "inner": .named("App.Inner")]),
        "App.Inner": .struct(["deep": .string, "beside": .int])
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a declared struct's field is lowered to its place")
    func aDeclaredFieldIsLoweredToItsPlace() async throws {
        // Given. The parameter says what it holds, so the build lays it out and
        // the position is the layout's.
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "point", type: .named("App.Point"))]
            ),
            body: [],
            result: .reference([.name("point"), .name("y")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then. `y` follows `x` in the layout's order.
        #expect(steps == [.field(1, "y", optional: false)])
    }

    @Test("a field of a struct literal is lowered to its place")
    func aLiteralFieldIsLoweredToItsPlace() async throws {
        // Given. The literal is written where the struct is declared, and laid
        // out the way the declaration is
        let sut = Procedure(
            body: [
                Statement(
                    binding: .constant("held", declared: .named("App.Pair")),
                    expression: .struct(["b": .literal(.int(2)), "a": .literal(.int(1))])
                )
            ],
            result: .reference([.name("held"), .name("b")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then
        #expect(steps == [.field(1, "b", optional: false)])
    }

    @Test("a map's keys are the value's, so an entry is read by its key between brackets")
    func aMapIsReadByKey() async throws {
        // Given
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "entries", type: .dictionary(key: .string, value: .int))]
            ),
            body: [],
            result: .reference([.name("entries"), .index("a")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then
        #expect(steps == [.index("a", optional: false)])
    }

    @Test("a place is read at every depth the build laid out")
    func nestedFieldsAreLoweredToTheirPlaces() async throws {
        // Given
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "outer", type: .named("App.Outer"))]
            ),
            body: [],
            result: .reference([.name("outer"), .name("inner"), .name("deep")])
        )

        // When
        let steps = try await resultSteps(of: sut)

        // Then. `inner` follows `head`, and `deep` follows `beside`
        #expect(steps == [.field(1, "inner", optional: false), .field(1, "deep", optional: false)])
    }

    @Test("a value from outside carrying more than the slot declares is read at the slot's places")
    func aValueFromOutsideIsFittedToTheDeclaredLayout() async throws {
        // Given. The argument holds fields the slot does not declare. The
        // door fits it to the slot's layout, so the place the build lowered
        // is the place the field stands in.
        let sut = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "point", type: .named("App.Point"))]
            ),
            body: [],
            result: .reference([.name("point"), .name("y")])
        )

        // When
        let answer = try await run(
            sut,
            arguments: [
                "point": .struct(Struct(name: "App.Point", ["a": .int(0), "x": .int(1), "y": .int(2), "z": .int(3)]))
            ]
        )

        // Then
        #expect(answer == .int(2))
    }

    @Test("a box that said what it holds is read by its place")
    func aDeclaredBoxIsReadByItsPlace() async throws {
        // Given. A value read as `Any` cast to what the box said it holds is
        // laid out the way the declaration says, and a place reads it.
        let sut = Procedure(
            signature: Signature(parameters: [Parameter(name: "given", type: .any)]),
            body: [
                Statement(
                    binding: .variable("point", declared: .named("App.Point")),
                    expression: .struct(["x": .literal(.int(1)), "y": .literal(.int(2))])
                ),
                Statement(
                    binding: .assignment([PathSegment.name("point")]),
                    expression: .cast(.reference([.name("given")]), as: .named("App.Point"), optional: false)
                )
            ],
            result: .reference([.name("point"), .name("y")])
        )

        // When
        let steps = try await resultSteps(of: sut)
        let answer = try await run(
            sut,
            arguments: [
                "given": .struct(Struct(name: "App.Point", ["x": .int(1), "y": .int(2)]))
            ]
        )

        // Then
        #expect(steps == [.field(1, "y", optional: false)])
        #expect(answer == .int(2))
    }

    @Test("a write to a box that said nothing stands as it was handed")
    func aBoxSayingNothingTakesWhatItWasHanded() async throws {
        // Given. Nothing was declared, so there is nothing for a write to
        // be held to and nothing the build laid out
        let sut = Procedure(
            signature: Signature(parameters: [Parameter(name: "given", type: .dictionary(key: .string, value: .int))]),
            body: [
                Statement(binding: .variable("held"), expression: map(["y": .literal(.int(0))])),
                Statement(
                    binding: .assignment([PathSegment.name("held")]),
                    expression: .reference([.name("given")])
                )
            ],
            result: .reference([.name("held"), .index("y")])
        )

        // When
        let steps = try await resultSteps(of: sut)
        let answer = try await run(
            sut,
            arguments: ["given": .dictionary(["a": .int(0), "y": .int(2)])]
        )

        // Then
        #expect(steps == [.index("y", optional: false)])
        #expect(answer == .int(2))
    }

    // MARK: - Public
    // MARK: - Private
    // The steps of the path a body answers with, which is where these tests
    // read what the build lowered.
    private func resultSteps(of procedure: Procedure) async throws -> [Step] {
        let image = try await builder.build(
            [try Module(types: Self.types, procedures: [entryName: procedure.with(access: .public)])] + Module.standard
        )

        return try steps(of: image)
    }

    // The procedure run as the entry of a module declaring the structs.
    private func run(_ procedure: Procedure, arguments: [Name: Value]) async throws -> Value {
        try await WarpTestSupport.run(
            try Module(types: Self.types, procedures: [entryName: procedure.with(access: .public)]),
            arguments: arguments
        )
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

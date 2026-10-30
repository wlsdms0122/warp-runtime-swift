//
//  LiteralRefusalTests.swift
//  WarpTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// Where a list or dictionary literal judged part by part is refused: at the first
// part its slot does not take, with that part and what the slot asks there
// spelled as types.
@Suite("A literal is refused at the part that does not fit")
struct LiteralRefusalTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a returned list is refused at its element")
    func aReturnedListIsRefusedAtItsElement() async throws {
        // Given
        let sut = try module(
            returning: .array(.int),
            [returning(.array([.literal(.int(1)), .literal(.string("a"))]))]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(refusal?.message == "returns String, and its declaration promises Int")
        #expect(refusal?.place?.rendered == "procedures.entry.body[0].leave[1]")
    }

    @Test("a list written into a name that declares its type is refused at its element")
    func aDeclaredNameIsRefusedAtTheElement() async throws {
        // Given
        let sut = try module(
            returning: .int,
            [
                Statement(
                    binding: .constant("xs", declared: .array(.int)),
                    expression: .array([.literal(.int(1)), .literal(.string("a"))])
                ),
                returning(.literal(.int(0)))
            ]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(refusal?.message == "holds Int, and what it was given is String")
        #expect(refusal?.place?.rendered == "procedures.entry.body.xs[0].array[1]")
    }

    @Test("a list a write sets is refused at its element, the path naming it")
    func aWriteIsRefusedAtTheElement() async throws {
        // Given
        let sut = try module(
            returning: .int,
            [
                Statement(binding: .variable("xs", declared: .array(.int)), expression: .array([])),
                Statement(
                    binding: .assignment([.name("xs")]),
                    expression: .array([.literal(.int(1)), .literal(.string("a"))])
                ),
                returning(.literal(.int(0)))
            ]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(refusal?.message == "writes 'xs[1]' as String, and it holds Int")
        #expect(refusal?.place?.rendered == "procedures.entry.body.xs[1].array[1]")
    }

    @Test("a dictionary handed to a call is refused at the key that does not fit, the parameter naming it")
    func anArgumentIsRefusedAtTheEntryKey() async throws {
        // Given
        let sut = try module(
            returning: .int,
            [
                returning(.call(Call(selector: "App.f", arguments: [
                    .dictionary([
                        (key: .literal(.string("a")), value: .literal(.int(1))),
                        (key: .literal(.int(2)), value: .literal(.int(3)))
                    ])
                ])))
            ],
            beside: [
                "App.f": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "d", type: .dictionary(key: .string, value: .int))],
                        returns: .int
                    ),
                    body: [returning(.literal(.int(0)))]
                )
            ]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(refusal?.message == "sending 'App.f' with d.entries[1][0], which holds Int where String is declared")
        #expect(refusal?.place?.rendered == "procedures.entry.body[0].leave.arguments[0].entries[1][0]")
    }

    @Test("a list a struct literal's field holds is refused at its element, the field naming it")
    func aFieldIsRefusedAtTheElement() async throws {
        // Given
        let sut = try module(
            returning: .int,
            [
                Statement(
                    binding: .constant("q", declared: .named("App.Q")),
                    expression: .struct(["xs": .array([.literal(.int(1)), .literal(.string("a"))])])
                ),
                returning(.literal(.int(0)))
            ],
            types: ["App.Q": .struct(["xs": .array(.int)])]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(refusal?.message == "a struct literal read as App.Q writes xs[1], which holds String where Int is declared")
        #expect(refusal?.place?.rendered == "procedures.entry.body.q[0].struct.fields.xs[1]")
    }

    @Test("a list handed where a bounded parameter stands is refused at the element its bounds refuse")
    func aBoundedParameterIsRefusedAtTheElement() async throws {
        // Given
        let read = ProcedureType(returns: .parameter(name: "N"), failing: .anything)
        let sut = try module(
            returning: .int,
            [
                returning(.call(Call(selector: "App.f", arguments: [
                    .array([
                        .closure(Procedure(signature: Signature(returns: .int), body: [returning(.literal(.int(1)))])),
                        .closure(Procedure(signature: Signature(returns: .string), body: [returning(.literal(.string("a")))]))
                    ])
                ])))
            ],
            beside: [
                "App.f": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "gs", type: .array(.procedure(read)))],
                        returns: .int,
                        bounds: ["N": ["Standard.Numeric"]]
                    ),
                    body: [returning(.literal(.int(0)))]
                )
            ]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(
            refusal?.message == "sending 'App.f': 'gs[1]' holds () -> String"
                + " where () throws -> some N: Standard.Numeric is declared"
        )
        #expect(refusal?.place?.rendered == "procedures.entry.body[0].leave.arguments[0][1]")
    }

    @Test("a value that is no literal is refused as a whole")
    func aValueIsRefusedWhole() async throws {
        // Given
        let sut = try module(
            returning: .array(.int),
            [
                Statement(binding: .constant("xs"), expression: .array([.literal(.string("a"))])),
                returning(reference("xs"))
            ]
        )

        // When
        let refusal = await refusal(building: sut)

        // Then
        #expect(refusal?.message == "returns Array<String>, and its declaration promises Array<Int>")
        #expect(refusal?.place?.rendered == "procedures.entry.body[1].leave")
    }

    // MARK: - Public
    // MARK: - Private
    // A module whose entry returns what `returns` declares, beside the
    // procedures and types it reads.
    private func module(
        returning returns: TypeExpression,
        _ body: Body,
        beside procedures: [Name: Procedure] = [:],
        types: [Name: TypeDeclaration] = [:]
    ) throws -> Module {
        let entry = Procedure(access: .public, signature: Signature(returns: returns), body: body)

        return try Module(types: types, procedures: procedures.merging([entryName: entry]) { kept, _ in kept })
    }

    private func refusal(building module: Module) async -> BuildError? {
        await #expect(throws: BuildError.self) {
            try await Builder().build([module] + Module.standard)
        }
    }
}

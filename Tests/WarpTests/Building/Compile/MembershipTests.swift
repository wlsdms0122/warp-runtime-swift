//
//  MembershipTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// A declared membership standing as a type. `A or B` is written the one way
// the language writes a set of types, by declaring it and naming it, so a
// slot saying "either of these" says something the build can hold to, where it
// used to have to say `any` and mean nothing.
@Suite("A membership as a type")
struct MembershipTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a member stands where the membership is declared")
    func aMemberFitsTheMembership() async throws {
        // Given
        let sut = try Module(
            constraints: ["app.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "app.hold", arguments: [.literal(.string("a"))]))
                ),
                "app.hold": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .named("app.Text"))],
                        returns: .named("app.Text")
                    ),
                    body: [],
                    result: reference("it")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .string("a"))
    }

    @Test("what the membership does not admit refuses at the build")
    func anOutsiderRefuses() async throws {
        // Given
        let sut = try Module(
            constraints: ["app.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "app.hold", arguments: [.literal(.int(1))]))
                ),
                "app.hold": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("app.Text"))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a value of a membership stands only where every member would")
    func aMembershipStandsWhereAllMembersDo() async throws {
        // Given. `string` takes one of the two, so the whole membership does
        // not fit it
        let sut = try Module(
            constraints: ["app.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("app.Text"))]),
                    body: [],
                    result: .call(Call(selector: "app.narrow", arguments: [reference("it")]))
                ),
                "app.narrow": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .string)]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a cast to a member opens it, and a cast to an outsider refuses")
    func aCastTellsTheMembersApart() async throws {
        // Given
        func module(reading type: TypeExpression) async throws -> Module {
            try Module(
                constraints: ["app.Text": [.string, .array(.byteElement)]],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "it", type: .named("app.Text"))]),
                        body: [.init(binding: .constant("narrowed"), expression: .cast(
                            reference("it"),
                            as: type,
                            optional: true
                        ))],
                        result: reference("narrowed")
                    )
                ]
            )
        }

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([try module(reading: .string)] + Module.standard)
        }
        await #expect(throws: BuildError.self) {
            try await Builder().build([try module(reading: .int)] + Module.standard)
        }
    }

    @Test("a value arriving from outside is judged against the membership")
    func theBoundaryAsksTheMembership() async throws {
        // Given. The declaration is what the argument meets, and an argument
        // is what only the run can see
        let sut = try Module(
            constraints: ["app.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("app.Text"))]),
                    body: [],
                    result: reference("it")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["it": .string("a")]) == .string("a"))

        await #expect(throws: (any Error).self) {
            try await run(sut, arguments: ["it": .int(1)])
        }
    }

    // MARK: - Public
    // MARK: - Private
}

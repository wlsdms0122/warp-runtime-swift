//
//  MembershipTests.swift
//  WarpTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// A declared membership standing as a type. `A or B` is written by declaring
// the set and naming it, so a slot saying "either of these" says something the
// build can hold to.
@Suite("A membership as a type")
struct MembershipTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a member stands where the membership is declared")
    func aMemberFitsTheMembership() async throws {
        // Given
        let sut = try Module(
            constraints: ["App.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "App.hold", arguments: [.literal(.string("a"))]))
                ),
                "App.hold": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .named("App.Text"))],
                        returns: .named("App.Text")
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
            constraints: ["App.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "App.hold", arguments: [.literal(.int(1))]))
                ),
                "App.hold": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("App.Text"))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'App.hold': 'it' holds Int, which 'App.Text' does not admit")
        }
    }

    @Test("a value of a membership stands only where every member would")
    func aMembershipStandsWhereAllMembersDo() async throws {
        // Given. `String` takes one of the two, so the whole membership does
        // not fit it
        let sut = try Module(
            constraints: ["App.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("App.Text"))]),
                    body: [],
                    result: .call(Call(selector: "App.narrow", arguments: [reference("it")]))
                ),
                "App.narrow": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .string)]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'App.narrow' with it, which holds App.Text where String is declared")
        }
    }

    @Test("a cast to a member opens it, and a cast to an outsider refuses")
    func aCastTellsTheMembersApart() async throws {
        // Given
        func module(reading type: TypeExpression) throws -> Module {
            try Module(
                constraints: ["App.Text": [.string, .array(.byteElement)]],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "it", type: .named("App.Text"))]),
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
        await #expect {
            try await Builder().build([try module(reading: .int)] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("reads App.Text as Int, and no value is both")
        }
    }

    @Test("a value arriving from outside is judged against the membership")
    func theBoundaryAsksTheMembership() async throws {
        // Given. The declaration is what the argument meets, and an argument
        // is what only the run can see
        let sut = try Module(
            constraints: ["App.Text": [.string, .array(.byteElement)]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("App.Text"))]),
                    body: [],
                    result: reference("it")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["it": .string("a")]) == .string("a"))

        await #expect {
            try await run(sut, arguments: ["it": .int(1)])
        } throws: { error in
            error is ArgumentError && "\(error)".contains("expected App.Text, and nothing 'App.Text' admits takes Int")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  IsolationTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// Isolation is derived for a body and declared by a native procedure. The build can
// read what a body writes and calls; it cannot read what a procedure keeps in the
// host language, so the procedure says. A procedure that says nothing is isolated, and
// one that holds state says otherwise and takes its callers with it.
@Suite("What may run beside something else")
struct IsolationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure that says nothing about itself is isolated")
    func aSilentProcedureIsIsolated() async throws {
        // Given. `app.shout` declares no isolation, so it takes the default
        let sut = try Module(
            imports: ["app.shout"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "app.shout", arguments: [.literal(.string("hi"))]))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut, .shouting] + Module.standard)

        // Then
        #expect(image[entryName]?.isolation == .isolated)
    }

    @Test("a procedure that holds state is not isolated, and neither is what calls it")
    func aStatefulProcedureStrikesItsCallers() async throws {
        // Given
        let sut = try Module(
            imports: ["app.ticket"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "app.reach"))
                ),
                "app.reach": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "app.ticket"))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut, .ticketing] + Module.standard)

        // Then. The procedure itself, and the body one hop away from it
        #expect(image["app.ticket"]?.isolation == .unstated)
        #expect(image["app.reach"]?.isolation == .unstated)
        #expect(image[entryName]?.isolation == .unstated)
    }

    @Test("a closure reaching a procedure that holds state is refused where isolation is asked")
    func aStatefulClosureIsRefusedBesideAnother() async throws {
        // Given. Two pieces to run at once, one of them reaching the box
        let sut = try Module(
            imports: ["app.ticket", "std.concurrent.all"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(
                        Call(
                            selector: "std.concurrent.all",
                            arguments: [
                                .record([
                                    "left": .closure(Procedure(body: [], result: .literal(.int(1)))),
                                    "right": .closure(
                                        Procedure(body: [], result: .call(Call(selector: "app.ticket")))
                                    )
                                ])
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: (any Error).self) {
            try await run([sut, .ticketing])
        }
    }

    @Test("answering without running does not make a body isolated")
    func constnessDoesNotAnswerIsolation() async throws {
        // Given. Nothing here runs, and the box is still shared
        let sut = try Module(
            imports: ["app.ticket"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "app.ticket"))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut, .ticketing] + Module.standard)

        // Then
        #expect(image[entryName]?.constness == .const)
        #expect(image[entryName]?.isolation == .unstated)
    }

    // MARK: - Public
    // MARK: - Private
}

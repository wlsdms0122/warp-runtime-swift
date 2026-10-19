//
//  IsolationTests.swift
//  WarpTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// Isolation is declared. The build holds a body declared isolated to what it
// writes and calls; it cannot read what a procedure keeps in the host
// language, so the host's declaration says.
@Suite("What may run beside something else")
struct IsolationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body declared isolated calling an isolated procedure is isolated")
    func anIsolatedBodyCallingAnIsolatedProcedureBuilds() async throws {
        // Given. `App.shout` is declared isolated
        let sut = try Module(
            imports: ["App.shout"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string, isolation: .isolated),
                    body: [],
                    result: .call(Call(selector: "App.shout", arguments: [.literal(.string("hi"))]))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut, .shouting] + Module.standard)

        // Then
        #expect(image[entryName]?.signature.isolation == .isolated)
    }

    @Test("a body declared isolated calling a procedure that holds state refuses")
    func anIsolatedBodyCallingAStatefulProcedureRefuses() async throws {
        // Given
        let sut = try Module(
            imports: ["App.ticket"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "App.reach"))
                ),
                "App.reach": Procedure(
                    signature: Signature(returns: .int, isolation: .isolated),
                    body: [],
                    result: .call(Call(selector: "App.ticket"))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut, .ticketing] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("calls 'App.ticket', which is not declared isolated")
        }
    }

    @Test("a closure declared isolated reaching a procedure that holds state refuses")
    func anIsolatedClosureReachingStateRefuses() async throws {
        // Given. Two pieces to run at once, one of them reaching the box
        let piece = Signature(returns: .int, isolation: .isolated)
        let sut = try Module(
            imports: ["App.ticket", "Standard.Concurrent.allKeyed"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any, failing: .anything),
                    body: [],
                    result: .call(
                        Call(
                            selector: "Standard.Concurrent.allKeyed",
                            arguments: [
                                map([
                                    "left": .closure(Procedure(signature: piece, body: [], result: .literal(.int(1)))),
                                    "right": .closure(
                                        Procedure(signature: piece, body: [], result: .call(Call(selector: "App.ticket")))
                                    )
                                ])
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await run([sut, .ticketing])
        } throws: { error in
            error is BuildError && "\(error)".contains("calls 'App.ticket', which is not declared isolated")
        }
    }

    @Test("a body declared const is not thereby isolated")
    func constnessDoesNotAnswerIsolation() async throws {
        // Given. Nothing here runs, and the box is still shared
        let sut = try Module(
            imports: ["App.ticket"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int, constness: .const),
                    body: [],
                    result: .call(Call(selector: "App.ticket"))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut, .ticketing] + Module.standard)

        // Then
        #expect(image[entryName]?.signature.constness == .const)
        #expect(image[entryName]?.signature.isolation == .unstated)
    }

    // MARK: - Public
    // MARK: - Private
}

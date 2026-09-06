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

// Isolation is derived for a body and declared by a native word. The link can
// read what a body writes and calls; it cannot read what a word keeps in the
// host language, so the word says. A word that says nothing is isolated, and
// one that holds state says otherwise and takes its callers with it.
@Suite("What may run beside something else")
struct IsolationTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a word that says nothing about itself is isolated")
    func aSilentWordIsIsolated() throws {
        // Given. `app.shout` declares no isolation, so it takes the default
        let sut = try Module(
            imports: ["app.shout"],
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(Call(selector: "app.shout", arguments: ["text": .literal(.string("hi"))]))
                )
            ]
        )

        // When
        let image = try Linker().link([sut, .shouting] + Module.standard, entry: entryName)

        // Then
        #expect(image[entryName]?.isolation == .isolated)
    }

    @Test("a word that holds state is not isolated, and neither is what calls it")
    func aStatefulWordStrikesItsCallers() throws {
        // Given
        let sut = try Module(
            imports: ["app.ticket"],
            procedures: [
                entryName: Procedure(
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
        let image = try Linker().link([sut, .ticketing] + Module.standard, entry: entryName)

        // Then. The word itself, and the body one hop away from it
        #expect(image["app.ticket"]?.isolation == .unstated)
        #expect(image["app.reach"]?.isolation == .unstated)
        #expect(image[entryName]?.isolation == .unstated)
    }

    @Test("a closure reaching a word that holds state is refused where isolation is asked")
    func aStatefulClosureIsRefusedBesideAnother() async throws {
        // Given. Two pieces to run at once, one of them reaching the box
        let sut = try Module(
            imports: ["app.ticket", "std.concurrent.all"],
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(
                        Call(
                            receiver: .record([
                                "left": .closure(Procedure(body: [], result: .literal(.int(1)))),
                                "right": .closure(
                                    Procedure(body: [], result: .call(Call(selector: "app.ticket")))
                                )
                            ]),
                            selector: "std.concurrent.all"
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

    @Test("a pure body is not isolated by being pure")
    func purityDoesNotAnswerIsolation() throws {
        // Given. Nothing here runs, and the box is still shared
        let sut = try Module(
            imports: ["app.ticket"],
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(Call(selector: "app.ticket"))
                )
            ]
        )

        // When
        let image = try Linker().link([sut, .ticketing] + Module.standard, entry: entryName)

        // Then
        #expect(image[entryName]?.purity == .pure)
        #expect(image[entryName]?.isolation == .unstated)
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ObjectClosureTests.swift
//  WarpTests
//
//  Created by JSilver on 9/18/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// A closure a fold settled into a value, written down and read back. An
// object spells it by the declaration that wrote it and which of that
// declaration's it is, and the link reading the object answers the row: the
// row the fold had is the fold's link's, and no object holds one.
@Suite("An object a procedure settled into")
struct ObjectClosureTests {
    // MARK: - Property
    private let builder = Builder(fingerprinting: Fingerprint.of)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a module variable starting as a closure comes back and runs")
    func aVariableThatStartsAsAProcedure() async throws {
        // Given
        let sut = try Module(
            variables: ["app.later": .closure(answering(7))],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.later"), arguments: [:])
                )
            ]
        )

        // When
        let answer = try await roundTripped(sut, entry: "app.entry")

        // Then
        #expect(answer == .int(7))
    }

    @Test("a literal a body folded from a closure comes back and runs")
    func aLiteralFoldedFromAProcedure() async throws {
        // Given
        let sut = try Module(
            constants: ["app.made": .closure(answering(5))],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.made"), arguments: [:])
                )
            ]
        )

        // When
        let answer = try await roundTripped(sut, entry: "app.entry")

        // Then
        #expect(answer == .int(5))
    }

    @Test("a closure folded out of another document's procedure comes back and runs")
    func aClosureFoldedAcrossDocuments() async throws {
        // Given. The closure captures a name by copy, so what it holds
        // travels with it
        let maker = try Module(
            procedures: [
                "app.make": Procedure(
                    signature: Signature(returns: .procedure(Signature(returns: .int))),
                    body: [Statement(binding: .constant("x"), expression: .literal(.int(11)))],
                    result: .closure(Procedure(signature: Signature(returns: .int), body: [], result: reference("x")))
                )
            ]
        )
        let sut = try Module(
            imports: ["app.make"],
            variables: ["app.held": .call(Call(selector: "app.make"))],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.held"), arguments: [:])
                )
            ]
        )

        // When
        let answer = try await roundTripped(sut, beside: [maker], entry: "app.entry")

        // Then
        #expect(answer == .int(11))
    }

    // MARK: - Private
    private func answering(_ number: Int) -> Procedure {
        Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(number)))
    }

    // The module compiled beside the vocabulary and the documents it leans
    // on, every object written to bytes and read back, and the run's answer.
    private func roundTripped(_ module: Module, beside others: [Module] = [], entry: Name) async throws -> Value? {
        let compiled = try await builder.compile(Module.standard + others + [module])
        let read = try compiled.map { one -> Compiled in
            let written = try #require(one.written, "an object is written for \(one.document.spelled(at: 0))")

            return try Compiled(written: written, of: one.document.identity)
        }
        let image = try await builder.link(read, entry: entry, supplying: Supplying(Module.standard))

        return try await Executor().run(image)
    }
}

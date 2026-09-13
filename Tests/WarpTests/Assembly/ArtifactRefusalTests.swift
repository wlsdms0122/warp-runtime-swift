//
//  ArtifactRefusalTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What an artifact refuses to be written as.
//
// A closure settled into a value holds the row a link gave it, and an artifact
// holds no row of any link. Both ways one reaches an artifact are held here,
// because they are two different foldings and the refusal is one.
@Suite("An artifact a procedure settled into")
struct ArtifactRefusalTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a module variable starts as one")
    func aVariableThatStartsAsAProcedure() throws {
        // Given. A variable whose starting value is a closure, which links and
        // runs: the refusal is about writing it down and not about the program.
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

        let compiled = try builder.compile([sut] + Module.standard)

        // When / Then. The program stands, and no artifact of it is written.
        #expect(throws: Never.self) {
            try builder.link(compiled, entry: "app.entry", supplying: Supplying(Module.standard))
        }

        #expect(throws: ArtifactRefused.self) {
            try compiled.map { one in try one.written }
        }
    }

    @Test("is refused where a body folds one into a literal")
    func aLiteralFoldedFromAProcedure() throws {
        // Given. A constant that is a closure, which folding stands in the body
        // that applies it.
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

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try builder.compile([sut] + Module.standard).map { one in try one.written }
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func answering(_ number: Int) -> Procedure {
        Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(number)))
    }
}

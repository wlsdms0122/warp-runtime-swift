//
//  LinkBoundaryTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// A procedure value carries its row, and a row is numbered by the link that
// made it. The two facts together are why a run holds one to the link it came
// from: the number means a declaration of that link and nothing about any
// other, so a row read where it was not made reads whatever stands at its
// number there.
//
// Not a conformance case: the question needs two images at once, and a case
// holds one document.
@Suite("A row is read where the link that made it is read")
struct LinkBoundaryTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a row's number means a different declaration in another link")
    func aRowNumberMeansAnotherDeclaration() async throws {
        // Given. Two links declaring different sets of type names. Names are
        // numbered in the order they sort, so one more name ahead of `Thing`
        // moves what its number stands for
        let mine = try Builder().build(
            try world(declaring: ["app.Thing": .record(["a": .int])]),
            entry: "entry"
        )
        let theirs = try Builder().build(
            try world(declaring: [
                "app.Alpha": .record(["z": .string]),
                "app.Thing": .record(["a": .int])
            ]),
            entry: "entry"
        )

        // When. A procedure value leaves the run that made it
        guard case let .procedure(closure) = try await Executor().run(mine, arguments: [:]) else {
            Issue.record("the entry answers a procedure")

            return
        }

        guard case let .named(row) = closure.linked.slots[0].shape else {
            Issue.record("the parameter is declared as a name")

            return
        }

        // Then. One number, two declarations
        #expect(mine.types.loweredTypes.labels[row] == "app.Thing")
        #expect(theirs.types.loweredTypes.labels[row] == "app.Alpha")

        // And the run refuses it rather than reading the other declaration
        #expect(closure.linked.readable(in: mine.types.loweredTypes))
        #expect(!closure.linked.readable(in: theirs.types.loweredTypes))
    }

    // MARK: - Private
    // A document that hands out a procedure taking one of its declared types.
    private func world(declaring types: [Name: TypeExpression]) throws -> [Module] {
        [
            try Module(Draft(
                types: types,
                procedures: [
                    "app.hand": Procedure(
                        signature: Signature(returns: .any),
                        body: [],
                        result: .closure(Procedure(
                            signature: Signature(
                                parameters: ["it": Parameter(type: .named("app.Thing"))],
                                returns: .any
                            ),
                            body: [],
                            result: .reference([.key("it")])
                        ))
                    ),
                    "entry": Procedure(
                        signature: Signature(returns: .any),
                        body: [],
                        result: .call(Call(selector: "app.hand"))
                    )
                ]
            ))
        ] + Module.standard
    }
}

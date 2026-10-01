//
//  TypeNamespaceTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp

// The types of a link are read the same whatever order the host handed its
// documents over in. What stands behind what is the graph's to say, and the
// namespace judges every space whole.
@Suite
struct TypeNamespaceTests {
    // MARK: - Property
    private let builder = Builder { value in Fingerprint(Array("\(value)".utf8)) }

    // `c` names a type of `b`, which names one of `a`, so they stand a, b, c
    // however they are handed over.
    private let modules: [Module] = [
        try! Module(
            types: ["a.T": .record(["x": .int]), "a.S": .string],
            procedures: [
                "a.make": Procedure(
                    access: .public,
                    signature: Signature(returns: .named("a.T")),
                    body: [],
                    result: .record(["x": .literal(.int(3))])
                )
            ],
            identity: Identity([0x0a])
        ),
        try! Module(
            types: ["b.U": .array(.named("a.T"))],
            procedures: [
                "b.use": Procedure(
                    access: .public,
                    signature: Signature(returns: .named("b.U")),
                    body: [],
                    result: .array([.call(Call(selector: "a.make"))])
                )
            ],
            identity: Identity([0x0b])
        ),
        try! Module(
            types: ["c.V": .record(["u": .named("b.U")])],
            procedures: [
                "c.go": Procedure(
                    access: .public,
                    signature: Signature(returns: .named("c.V")),
                    body: [],
                    result: .record(["u": .call(Call(selector: "b.use"))])
                )
            ],
            identity: Identity([0x0c])
        )
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document compiles to the same object whatever order the documents were handed over in", arguments: [
        [2, 1, 0],
        [1, 2, 0],
        [2, 0, 1]
    ])
    func objectsDoNotFollowTheHandedOrder(_ order: [Int]) async throws {
        // Given
        let standing = try await objects(handing: [0, 1, 2])

        // When
        let shuffled = try await objects(handing: order)

        // Then
        #expect(shuffled == standing)
    }

    @Test("a name declared as a type and as a constraint is refused the same way in either order")
    func aTypeAndAConstraintAreRefusedInEitherOrder() async throws {
        // Given
        let typing = try Module(types: ["t.T": .int], procedures: [:], identity: Identity([0x01]))
        let constraining = try Module(constraints: ["t.T": [.int]], procedures: [:], identity: Identity([0x02]))

        for given in [[typing, constraining], [constraining, typing]] {
            // When
            let refused = await #expect(throws: BuildError.self) {
                try await builder.build(given + Module.standard)
            }

            // Then
            #expect(refused?.message.contains("declared as both a type and a constraint") == true)
            #expect(refused?.place == .constraint("t.T", in: .of(constraining)))
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Each document's object by its identity, compiled from the modules handed
    // over in `order`.
    private func objects(handing order: [Int]) async throws -> [Identity: Value] {
        let compiled = try await builder.compile(order.map { position in modules[position] } + Module.standard)

        return try compiled.prefix(order.count).reduce(into: [Identity: Value]()) { objects, document in
            objects[try #require(document.identity)] = try document.object()
        }
    }
}

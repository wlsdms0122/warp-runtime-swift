//
//  TypeNamespaceTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// The types of a link are read the same whatever order the host handed its
// documents over in. What stands behind what is the graph's to say, and the
// namespace judges every space whole.
@Suite("The types of a link read alike in any order")
struct TypeNamespaceTests {
    // MARK: - Property
    private let builder = Builder { value in Fingerprint(Array("\(value)".utf8)) }

    // `c` names a type of `b`, which names one of `a`, so they stand a, b, c
    // however they are handed over.
    private let modules: [Module] = [
        try! Module(
            Draft(
                types: ["A.T": .struct(["x": .int]), "A.S": .alias(.string)],
                procedures: [
                    "A.make": Procedure(
                        access: .public,
                        signature: Signature(returns: .named("A.T")),
                        body: [returning(.struct(["x": .literal(.int(3))]))]
                    )
                ]
            ),
            identity: Identity([0x0a])
        ),
        try! Module(
            Draft(
                types: ["B.U": .alias(.array(.named("A.T")))],
                procedures: [
                    "B.use": Procedure(
                        access: .public,
                        signature: Signature(returns: .named("B.U")),
                        body: [returning(.array([.call(Call(selector: "A.make"))]))]
                    )
                ]
            ),
            identity: Identity([0x0b])
        ),
        try! Module(
            Draft(
                types: ["C.V": .struct(["u": .named("B.U")])],
                procedures: [
                    "C.go": Procedure(
                        access: .public,
                        signature: Signature(returns: .named("C.V")),
                        body: [returning(.struct(["u": .call(Call(selector: "B.use"))]))]
                    )
                ]
            ),
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

    @Test("a name declared as a type and as a contract is refused the same way in either order")
    func aTypeAndAContractAreRefusedInEitherOrder() async throws {
        // Given
        let typing = try Module(Draft(types: ["T.T": .alias(.int)]), identity: Identity([0x01]))
        let contracting = try Module(Draft(contracts: ["T.T": [:]]), identity: Identity([0x02]))

        for given in [[typing, contracting], [contracting, typing]] {
            // When
            let refused = await #expect(throws: BuildError.self) {
                try await builder.build(given + Module.standard)
            }

            // Then
            #expect(refused?.message.contains("declared as both a type and a contract") == true)
            #expect(refused?.place == .contract("T.T", in: .of(contracting)))
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

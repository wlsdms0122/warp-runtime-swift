//
//  ObjectInterfaceTests.swift
//  WarpTests
//
//  Created by JSilver on 11/4/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// What a compiled document's interface holds: what a document compiled
// against it reads, and none of what a compile never runs.
@Suite("An interface is what a document compiled against another reads of it")
struct ObjectInterfaceTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("stands alike where only a body that is not const changed")
    func aBodyAloneLeavesItAlike() async throws {
        // Given
        let one = try await compiled(declaring(returning: 1, constness: .unstated), identity: [0x01])
        let other = try await compiled(declaring(returning: 2, constness: .unstated), identity: [0x02])

        // When
        let sut = try one.interface()

        // Then
        #expect(sut == (try other.interface()))
        #expect(try one.object() != other.object())
    }

    @Test("changes where a const body changed")
    func aConstBodyChangesIt() async throws {
        // Given
        let one = try await compiled(declaring(returning: 1, constness: .const), identity: [0x01])
        let other = try await compiled(declaring(returning: 2, constness: .const), identity: [0x01])

        // When
        let sut = try one.interface()

        // Then
        #expect(sut != (try other.interface()))
    }

    @Test("changes where a signature changed")
    func aSignatureChangesIt() async throws {
        // Given
        let one = try await compiled(declaring(returning: 1, constness: .unstated), identity: [0x01])
        let other = try await compiled(
            [
                "A.foo": Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [returning(.literal(.string("1")))]
                )
            ],
            identity: [0x01]
        )

        // When
        let sut = try one.interface()

        // Then
        #expect(sut != (try other.interface()))
    }

    @Test("leaves out the closures a body that is not const wrote")
    func aClosureOfABodyNotConstIsLeftOut() async throws {
        // Given
        let one = try await compiled(making(returning: 1, constness: .unstated), identity: [0x01])
        let other = try await compiled(making(returning: 2, constness: .unstated), identity: [0x02])

        // When
        let sut = try one.interface()

        // Then
        #expect(sut == (try other.interface()))
    }

    @Test("keeps the closures a const body wrote, and the document they are spelled by")
    func aClosureOfAConstBodyIsKept() async throws {
        // Given
        let one = try await compiled(making(returning: 1, constness: .const), identity: [0x01])
        let other = try await compiled(making(returning: 1, constness: .const), identity: [0x02])

        // When
        let sut = try one.interface()

        // Then
        #expect(sut != (try other.interface()))
    }

    @Test("names no document where no closure it writes is kept")
    func aDocumentWithoutKeptClosuresIsUnnamed() async throws {
        // Given
        let one = try await compiled(declaring(returning: 1, constness: .const), identity: [0x01])
        let other = try await compiled(declaring(returning: 1, constness: .const), identity: [0x02])

        // When
        let sut = try one.interface()

        // Then
        #expect(sut == (try other.interface()))
    }

    // MARK: - Private
    private func compiled(_ procedures: [Name: Procedure], identity: [UInt8]) async throws -> Compiled {
        let module = try Module(Draft(procedures: procedures), identity: Identity(identity))

        return try #require(try await builder.compile([module]).first)
    }

    private func declaring(returning number: Int, constness: Constness) -> [Name: Procedure] {
        [
            "A.foo": Procedure(
                access: .public,
                signature: Signature(returns: .int, constness: constness),
                body: [returning(.literal(.int(number)))]
            )
        ]
    }

    // A procedure returning a closure it writes, which returns `number`.
    private func making(returning number: Int, constness: Constness) -> [Name: Procedure] {
        [
            "A.make": Procedure(
                access: .public,
                signature: Signature(
                    returns: .procedure(ProcedureType(returns: .int, failing: .anything)),
                    constness: constness
                ),
                body: [
                    returning(.closure(Procedure(signature: Signature(returns: .int), body: [returning(.literal(.int(number)))])))
                ]
            )
        ]
    }
}

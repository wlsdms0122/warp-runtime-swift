//
//  HostDoorTests.swift
//  WarpTests
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A host settles a value against a declaration the build holds")
struct HostDoorTests {
    // MARK: - Property
    private var sut: Module {
        get throws {
            try Module(
                imports: [],
                types: ["Bank.Account": .record(["balance": .int])],
                procedures: ["entry": Procedure(access: .public, implementation: .body(Block(body: [], result: .literal(.null))))]
            )
        }
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("settling against a declared type builds the value on that type's layout")
    func settlingByDeclarationNamesTheValue() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When
        let settled = try image.settling(.dictionary(["balance": .int(1)]), as: "Bank.Account")

        // Then
        guard case let .record(record) = settled else {
            Issue.record("the value did not settle to a record")

            return
        }

        #expect(record.name == "Bank.Account")
        #expect(record.names == ["balance"])
    }

    @Test("a declaration the build does not have refuses")
    func anUndeclaredNameIsRefused() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When / Then
        #expect(throws: ValueRefused.self) {
            try image.settling(.dictionary(["balance": .int(1)]), as: "Bank.Vault")
        }
    }

    @Test("a value the declaration does not admit refuses at the door")
    func aValueOutsideTheDeclarationIsRefused() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When / Then
        #expect {
            try image.settling(.dictionary(["balance": .string("much")]), as: "Bank.Account")
        } throws: { error in
            error is ArgumentError && "\(error)".contains("expected int, got string")
        }
    }

    @Test("a field the declaration never named is not carried past the door")
    func anUndeclaredFieldDoesNotRideThrough() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When
        let settled = try image.settling(
            .dictionary(["balance": .int(1), "note": .string("x")]),
            as: "Bank.Account"
        )

        // Then
        #expect(settled["note"] == nil)
        #expect(settled["balance"] == .int(1))
    }

    // MARK: - Public
    // MARK: - Private
}

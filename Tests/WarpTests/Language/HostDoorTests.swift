//
//  HostDoorTests.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A host builds a value through the doors, not by hand")
struct HostDoorTests {
    // MARK: - Test
    @Test("a name is written onto a value only by settling it against a declaration")
    func settlingByDeclarationNamesTheValue() throws {
        // Given
        let image = try Linker().link([sut], entry: "entry")

        // When
        let settled = try image.settling(.dictionary(["balance": .int(1)]), as: "bank.Account")

        // Then
        guard case let .record(record) = settled else {
            Issue.record("the value did not settle to a record")

            return
        }

        #expect(record.name == "bank.Account")
        #expect(record.names == ["balance"])
    }

    @Test("a declaration the link does not have refuses")
    func anUndeclaredNameIsRefused() throws {
        // Given
        let image = try Linker().link([sut], entry: "entry")

        // When / Then
        #expect(throws: ValueRefused.self) {
            try image.settling(.dictionary(["balance": .int(1)]), as: "bank.Vault")
        }
    }

    @Test("a value the declaration does not admit refuses at the door")
    func aValueOutsideTheDeclarationIsRefused() throws {
        // Given
        let image = try Linker().link([sut], entry: "entry")

        // When / Then
        #expect(throws: (any Error).self) {
            try image.settling(.dictionary(["balance": .string("much")]), as: "bank.Account")
        }
    }

    @Test("a field the declaration never named is not carried past the door")
    func anUndeclaredFieldDoesNotRideThrough() throws {
        // Given
        let image = try Linker().link([sut], entry: "entry")

        // When
        let settled = try image.settling(
            .dictionary(["balance": .int(1), "note": .string("x")]),
            as: "bank.Account"
        )

        // Then
        #expect(settled["note"] == nil)
        #expect(settled["balance"] == .int(1))
    }

    // MARK: - Private
    private var sut: Module {
        get throws {
            try Module(
                imports: [],
                types: ["bank.Account": .record(["balance": .int])],
                procedures: ["entry": Procedure(implementation: .body(Block(body: [], result: .literal(.null))))]
            )
        }
    }
}

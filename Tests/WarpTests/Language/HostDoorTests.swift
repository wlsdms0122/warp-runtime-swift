//
//  HostDoorTests.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A host settles a value against a declaration the build holds")
struct HostDoorTests {
    // MARK: - Test
    @Test("settling against a declared type builds the value on that type's layout")
    func settlingByDeclarationNamesTheValue() throws {
        // Given
        let image = try Builder().build([sut], entry: "entry")

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

    @Test("a declaration the build does not have refuses")
    func anUndeclaredNameIsRefused() throws {
        // Given
        let image = try Builder().build([sut], entry: "entry")

        // When / Then
        #expect(throws: ValueRefused.self) {
            try image.settling(.dictionary(["balance": .int(1)]), as: "bank.Vault")
        }
    }

    @Test("a value the declaration does not admit refuses at the door")
    func aValueOutsideTheDeclarationIsRefused() throws {
        // Given
        let image = try Builder().build([sut], entry: "entry")

        // When / Then
        #expect(throws: (any Error).self) {
            try image.settling(.dictionary(["balance": .string("much")]), as: "bank.Account")
        }
    }

    @Test("a field the declaration never named is not carried past the door")
    func anUndeclaredFieldDoesNotRideThrough() throws {
        // Given
        let image = try Builder().build([sut], entry: "entry")

        // When
        let settled = try image.settling(
            .dictionary(["balance": .int(1), "note": .string("x")]),
            as: "bank.Account"
        )

        // Then
        #expect(settled["note"] == nil)
        #expect(settled["balance"] == .int(1))
    }

    @Test("a dictionary slot takes a record and answers one whose names are data")
    func aRecordSettlesIntoADictionaryAsData() throws {
        // Given. A name is proved where a slot declares one, and a `dictionary`
        // slot declares none
        let image = try Builder().build([sut], entry: "entry")
        let named = try image.settling(.dictionary(["balance": .int(1)]), as: "bank.Account")

        // When
        let settled = try TypeExpression.dictionary(.any).settling(named, at: "held")

        // Then
        #expect(named == .record(Record(name: "bank.Account", ["balance": .int(1)])))
        #expect(settled == .dictionary(["balance": .int(1)]))
    }

    @Test("a layout a host builds carries no name of its own")
    func aHostBuiltLayoutHasNoName() throws {
        // Given. A name says a declaration, and a declaration is the build's
        let layout = try Layout(fields: ["balance"])

        // When
        let built = try Record(layout: layout, checking: [.int(1)])

        // Then
        #expect(built.name == nil)
        #expect(Value.record(built) == .dictionary(["balance": .int(1)]))
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

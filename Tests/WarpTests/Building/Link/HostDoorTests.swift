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
    // A procedure the host answers handing the closure it was given a map
    // holding a field the closure's parameter never names.
    private struct HandingQuery: Query {
        enum Parameters: Int, ParameterSet {
            case body

            // MARK: - Property
            var declared: Parameter {
                Parameter(
                    name: "body",
                    type: .procedure(ProcedureType(parameters: [.record(["id": .string])], returns: .string), .const)
                )
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            guard case let .procedure(closure) = question[.body] else {
                throw ExecutionError("App.handing asks a procedure")
            }

            return try await question.call(closure, handing: [.dictionary(["id": .string("a"), "extra": .int(1)])])
        }

        // MARK: - Private
    }

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
            error is ArgumentError && "\(error)".contains("expected Int, got String")
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

    @Test("a value a host hands a closure is fitted at the door")
    func aValueHandedToAClosureIsFitted() async throws {
        // Given
        let handing = try Module(
            procedures: [
                "App.handing": Procedure(
                    signature: Signature(of: HandingQuery.self, returns: .string),
                    implementation: .query(HandingQuery())
                )
            ]
        )
        let document = try Module(
            imports: ["App.handing"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "App.handing",
                        arguments: [
                            .closure(Procedure(
                                signature: Signature(parameters: [Parameter(name: "x", type: .record(["id": .string]))], returns: .string),
                                body: [],
                                result: .reference([.key("x"), .key("id")])
                            ))
                        ]
                    ))
                )
            ]
        )
        let image = try await Builder().build([document, handing])

        // When / Then
        #expect(try await Executor().run(image) == .string("a"))
    }

    // MARK: - Public
    // MARK: - Private
}

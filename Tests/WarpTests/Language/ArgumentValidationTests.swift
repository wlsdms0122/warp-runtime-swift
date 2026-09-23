//
//  ArgumentValidationTests.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A procedure judges its constant arguments at the build")
struct ArgumentValidationTests {
    // MARK: - Test
    @Test("a constant argument the procedure refuses is refused at the build")
    func aRefusedConstantIsRefusedAtTheBuild() async throws {
        // Given
        let odd = try Module(
            imports: ["app.even"],
            procedures: ["entry": Procedure(access: .public, body: [], result: even(.literal(.int(3))))]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([odd, Self.host])
        }
    }

    @Test("a constant argument the procedure accepts builds")
    func anAcceptedConstantBuilds() async throws {
        // Given
        let even = try Module(
            imports: ["app.even"],
            procedures: ["entry": Procedure(access: .public, body: [], result: even(.literal(.int(2))))]
        )

        // When / Then
        _ = try await Builder().build([even, Self.host])
    }

    // MARK: - Private
    private static let host = try! Module(
        procedures: [
            "app.even": Procedure(
                signature: Signature(of: EvenQuery.self, returns: .bool),
                implementation: .query(EvenQuery())
            )
        ]
    )

    private func even(_ value: Warp.Expression) -> Warp.Expression {
        .call(Call(selector: "app.even", arguments: ["value": value]))
    }
}

// A procedure that will not take an odd number, which is a fact about the
// value no type says.
private struct EvenQuery: Query {
    enum Parameters: Int, ParameterSet {
        case value

        var declared: Parameter { Parameter(name: "value", type: .int) }
    }

    // MARK: - Public
    func validate(_ question: Question<Self>) throws {
        guard case let .int(given) = question[.value], given % 2 != 0 else { return }

        throw ValidationError("even takes an even number, and \(given) is odd", at: nil)
    }

    func evaluate(_ question: Question<Self>) async throws -> Value? {
        .bool(true)
    }
}

//
//  ArgumentValidationTests.swift
//  WarpTests
//
//  Created by JSilver on 9/20/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A procedure judges its constant arguments at the build")
struct ArgumentValidationTests {
    // A procedure that will not take an odd number, which is a fact about the
    // value no type says.
    private struct EvenQuery: Query {
        enum Parameters: Int, ParameterSet {
            case value

            // MARK: - Property
            var declared: Parameter { Parameter(name: "value", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func validate(_ question: Question<Self>) throws {
            guard case let .int(given) = question[.value], given % 2 != 0 else { return }

            throw ValidationError("even takes an even number, and \(given) is odd", at: nil)
        }

        func evaluate(_ question: Question<Self>) async throws -> Value {
            .bool(true)
        }

        // MARK: - Private
    }

    // MARK: - Property
    private static let host = try! Module(
        procedures: [
            "app.even": Procedure(
                signature: Signature(of: EvenQuery.self, returns: .bool),
                implementation: .query(EvenQuery())
            )
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant argument the procedure refuses is refused at the build")
    func aRefusedConstantIsRefusedAtTheBuild() async throws {
        // Given
        let odd = try Module(
            imports: ["app.even"],
            procedures: ["entry": Procedure(access: .public, body: [], result: even(.literal(.int(3))))]
        )

        // When / Then
        await #expect {
            try await Builder().build([odd, Self.host])
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'app.even': even takes an even number, and 3 is odd")
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

    // MARK: - Public
    // MARK: - Private
    private func even(_ value: Warp.Expression) -> Warp.Expression {
        .call(Call(selector: "app.even", arguments: [value]))
    }
}

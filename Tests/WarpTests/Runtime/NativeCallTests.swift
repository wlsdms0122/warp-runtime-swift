//
//  NativeCallTests.swift
//  WarpTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A native procedure as the run calls it")
struct NativeCallTests {
    // A native procedure answering whether what it is handed holds a type.
    private struct PeekingQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter {
                Parameter(name: "of", type: .parameter(name: "T"))
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            .bool(question[.of].isExistential)
        }

        // MARK: - Private
    }

    // The same at `Any`.
    private struct PeekingAnyQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter {
                Parameter(name: "of", type: .any)
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            .bool(question[.of].isExistential)
        }

        // MARK: - Private
    }

    // A native procedure handing back what it is handed at a type parameter
    // a contract bounds.
    private struct PassingQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter {
                Parameter(name: "of", type: .parameter(name: "T"))
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            question[.of]
        }

        // MARK: - Private
    }

    // A native procedure writing back what the variable it was handed in
    // place holds.
    private struct KeepingEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter {
                Parameter(name: "of", type: .inout(.parameter(name: "T")))
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            try invocation.write(.of, try invocation.held(.of))

            return .null
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    private static let optional = Head(TypeSpelling.optional, arguments: [.parameter(name: "W")])

    // MARK: - Initializer
    // MARK: - Test
    @Test("hands back a value it was handed in place holding the type it was read as")
    func handsBackWhatItWasHandedInPlace() async throws {
        // Given. `x` holds 5 read as `Int?`, and `App.keep` writes back what it holds
        let module = try Self.describing([
            Statement(binding: .variable("x", declared: .named("App.Described")), expression: reference("maybe")),
            Statement(expression: .call(Call(selector: "App.keep", arguments: [reference("x")]))),
            returning(.call(Call(selector: "App.Described.describe", arguments: [reference("x")])))
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then. The row of the Optional, not of `Int`
        #expect(try await Executor().run(image) == .string("an optional"))
    }

    @Test("hands back at a bounded parameter what a value read as a contract filled it with")
    func handsBackWhatFilledABoundedParameter() async throws {
        // Given. `x` holds 5 read as `Int?`, and fills `T` of `App.pass` with it
        let module = try Self.describing([
            Statement(binding: .constant("x", declared: .named("App.Described")), expression: reference("maybe")),
            Statement(
                binding: .constant("back"),
                expression: .call(Call(selector: "App.pass", arguments: [reference("x")]))
            ),
            returning(.call(Call(selector: "App.Described.describe", arguments: [reference("back")])))
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then. The row of the Optional, not of `Int`
        #expect(try await Executor().run(image) == .string("an optional"))
    }

    @Test("is handed a value read as a contract with the type it holds, and at `Any` with none")
    func isHandedWhatTheRunHolds() async throws {
        // Given
        let module = try Self.describing([
            Statement(binding: .constant("x", declared: .named("App.Described")), expression: reference("maybe")),
            returning(
                .array([
                    .call(Call(selector: "App.peek", arguments: [reference("x")])),
                    .call(Call(selector: "App.peekAny", arguments: [reference("x")]))
                ])
            )
        ], returns: .array(.bool))

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .array([.bool(true), .bool(false)]))
    }

    // MARK: - Public
    // MARK: - Private
    // `Int` and every Optional describing themselves, the native
    // procedures above, and an entry starting from `maybe`, 5 read as `Int?`.
    private static func describing(_ body: [Statement], returns: TypeExpression = .string) throws -> Module {
        try Module(
            contracts: [
                "App.Described": [
                    "describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)
                ]
            ],
            claims: ["Int": ["App.Described"], optional: ["App.Described"]],
            members: ["Int": ["describe"], optional: ["describe"]],
            procedures: [
                "Int.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .string),
                    body: [returning(.literal(.string("a number")))]
                ),
                Name("describe").spelled(under: optional.type): Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .optional(.parameter(name: "W")))],
                        returns: .string
                    ),
                    body: [returning(.literal(.string("an optional")))]
                ),
                "App.peek": Procedure(
                    signature: Signature(of: PeekingQuery.self, returns: .bool),
                    implementation: .query(PeekingQuery())
                ),
                "App.peekAny": Procedure(
                    signature: Signature(of: PeekingAnyQuery.self, returns: .bool),
                    implementation: .query(PeekingAnyQuery())
                ),
                "App.pass": Procedure(
                    signature: Signature(
                        of: PassingQuery.self,
                        returns: .parameter(name: "T"),
                        bounds: ["T": ["App.Described"]]
                    ),
                    implementation: .query(PassingQuery())
                ),
                "App.keep": Procedure(
                    signature: Signature(of: KeepingEffect.self),
                    implementation: .effect(KeepingEffect())
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: returns),
                    body: Body(
                        [Statement(binding: .constant("maybe", declared: .optional(.int)), expression: .literal(.int(5)))] + body
                    )
                )
            ]
        )
    }
}

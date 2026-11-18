//
//  ComputationCallTests.swift
//  WarpTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A computation as the run asks it")
struct ComputationCallTests {
    // The digits it is handed, read as one number, so each argument says
    // which place it was read from.
    private struct DigitsComputation: Computation {
        enum Parameters: Int, ParameterSet {
            case hundreds
            case tens
            case ones

            // MARK: - Property
            var declared: Parameter {
                switch self {
                case .hundreds: Parameter(name: "hundreds", type: .int)
                case .tens: Parameter(name: "tens", type: .int)
                case .ones: Parameter(name: "ones", type: .int)
                }
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func compute(_ arguments: Arguments<Self>) throws -> Value {
            guard
                case let .int(hundreds) = arguments[.hundreds],
                case let .int(tens) = arguments[.tens],
                case let .int(ones) = arguments[.ones],
                [hundreds, tens, ones].allSatisfy((0...9).contains)
            else {
                throw RunRefused("App.digits takes three digits")
            }

            return .int(hundreds * 100 + tens * 10 + ones)
        }

        // MARK: - Private
    }

    // Handing back what it is handed, whatever its declaration says it
    // returns.
    private struct EchoComputation: Computation {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .string) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func compute(_ arguments: Arguments<Self>) throws -> Value {
            arguments[.of]
        }

        // MARK: - Private
    }

    // Writing 2 under "a" in the dictionary it is handed, and 1 under "kept"
    // where the write landed in the storage it was handed rather than a copy.
    // What it is handed second it only reads.
    private struct KeepComputation: Computation {
        enum Parameters: Int, ParameterSet {
            case into
            case also

            // MARK: - Property
            var declared: Parameter {
                switch self {
                case .into: Parameter(name: "into", type: .dictionary(key: .string, value: .int))
                case .also: Parameter(name: "also", type: .any)
                }
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func compute(_ arguments: Arguments<Self>) throws -> Value {
            try compute(taking: arguments)
        }

        func compute(taking arguments: consuming Arguments<Self>) throws -> Value {
            guard case var .dictionary(held) = arguments.take(.into) else {
                throw RunRefused("App.keep takes a dictionary")
            }

            let storage = Self.storage(of: held)

            try held.write(key: .string("a"), with: .int(2))

            let kept = Self.storage(of: held) == storage

            try held.write(key: .string("kept"), with: .int(kept ? 1 : 0))

            return .dictionary(held)
        }

        // MARK: - Private
        private static func storage(of held: Value.Dictionary) -> UnsafeRawPointer? {
            held.entries.withUnsafeBufferPointer { buffer in buffer.baseAddress.map(UnsafeRawPointer.init) }
        }
    }

    // Failing whatever it is handed.
    private struct FailComputation: Computation {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func compute(_ arguments: Arguments<Self>) throws -> Value {
            throw TestRecoverableFailure()
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("reads every argument its call wrote by its own key, past the second")
    func readsEveryArgument() async throws {
        // Given
        let module = try Self.asking([
            Statement(binding: .constant("tens"), expression: .literal(.int(2))),
            returning(
                .call(Call(selector: "App.digits", arguments: [.literal(.int(1)), reference("tens"), .literal(.int(3))]))
            )
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .int(123))
    }

    @Test("reads an argument that waits on a written body as it reads the others")
    func readsAnArgumentThatWaits() async throws {
        // Given. `App.two` has a body, so the second argument runs it
        let module = try Self.asking([
            returning(
                .call(
                    Call(
                        selector: "App.digits",
                        arguments: [.literal(.int(1)), .call(Call(selector: "App.two", arguments: [])), .literal(.int(3))]
                    )
                )
            )
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .int(123))
    }

    @Test("a value it answers is held to the type its declaration returns")
    func anAnswerIsHeldToItsReturns() async throws {
        // Given. `App.echo` is declared to return an Int and hands back a String
        let module = try Self.asking([
            returning(.call(Call(selector: "App.echo", arguments: [.literal(.string("five"))])))
        ])
        let image = try await builder.build([module] + Module.standard)

        // When / Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            error is DoorRefused && "\(error)".contains("returns: expected Int, got String")
        }
    }

    @Test("a refusal it throws stops the run")
    func aRefusalStopsTheRun() async throws {
        // Given. The second argument is no digit
        let module = try Self.asking([
            returning(
                .call(Call(selector: "App.digits", arguments: [.literal(.int(1)), .literal(.int(12)), .literal(.int(3))]))
            )
        ])
        let image = try await builder.build([module] + Module.standard)

        // When / Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            "\(error)".contains("App.digits takes three digits")
        }
    }

    @Test("is handed to keep the value of a variable its call reads last before the statement writes it")
    func isHandedTheValueOfAVariableReadLast() async throws {
        // Given
        let module = try Self.keeping([
            Statement(binding: .assignment([.name("held")]), expression: Self.keep(.literal(.int(0))))
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == Self.held(a: 2, kept: 1))
    }

    @Test("leaves a variable as it was where a try holds the write and an argument read after it fails")
    func leavesAVariableAWriteATryHoldsFailed() async throws {
        // Given
        let module = try Self.keeping([
            Statement(binding: .constant("fragile"), expression: .try(
                [
                    Statement(
                        binding: .assignment([.name("held")]),
                        expression: Self.keep(.call(Call(selector: "App.fail", arguments: [.literal(.int(0))])))
                    )
                ],
                catch: [Statement(binding: .constant("recovered"), expression: .literal(.bool(true)))]
            ))
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .dictionary(try Value.Dictionary([(key: .string("a"), value: .int(1))])))
    }

    @Test("reads a variable its call reads twice as what it holds both times")
    func readsAVariableReadTwice() async throws {
        // Given
        let module = try Self.keeping([
            Statement(
                binding: .assignment([.name("held")]),
                expression: Self.keep(reference("held"))
            )
        ])

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then. The write landed in a copy, since the variable still held it
        #expect(try await Executor().run(image) == Self.held(a: 2, kept: 0))
    }

    // MARK: - Public
    // MARK: - Private
    // The computations above, a body answering 2, and an entry returning an
    // Int from `body`.
    private static func asking(_ body: [Statement]) throws -> Module {
        try Module(
            procedures: [
                "App.digits": Procedure(
                    signature: Signature(of: DigitsComputation.self, returns: .int),
                    implementation: DigitsComputation()
                ),
                "App.echo": Procedure(
                    signature: Signature(of: EchoComputation.self, returns: .int),
                    implementation: EchoComputation()
                ),
                "App.two": Procedure(
                    signature: Signature(returns: .int, constness: .const),
                    body: Body([returning(.literal(.int(2)))])
                ),
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: Body(body))
            ]
        )
    }

    // `App.keep` writing into `held`, handed `also` second.
    private static func keep(_ also: Warp.Expression) -> Warp.Expression {
        .call(Call(selector: "App.keep", arguments: [reference("held"), also]))
    }

    private static func held(a: Int, kept: Int) throws -> Value {
        .dictionary(try Value.Dictionary([(key: .string("a"), value: .int(a)), (key: .string("kept"), value: .int(kept))]))
    }

    // The computations above and an entry returning `held`, a variable
    // holding 1 under "a", after `body`.
    private static func keeping(_ body: [Statement]) throws -> Module {
        let held = TypeExpression.dictionary(key: .string, value: .int)

        return try Module(
            procedures: [
                "App.keep": Procedure(
                    signature: Signature(of: KeepComputation.self, returns: held),
                    implementation: KeepComputation()
                ),
                "App.fail": Procedure(
                    signature: Signature(
                        of: FailComputation.self,
                        returns: .int,
                        failing: .these([TestRecoverableFailure.type]),
                        constness: .const
                    ),
                    implementation: FailComputation()
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: held),
                    body: Body(
                        [Statement(binding: .variable("held", declared: held), expression: dictionary(["a": .literal(.int(1))]))]
                            + body
                            + [returning(reference("held"))]
                    )
                )
            ]
        )
    }
}

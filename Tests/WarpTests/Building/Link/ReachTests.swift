//
//  ReachTests.swift
//  WarpTests
//
//  Created by JSilver on 9/17/26.
//

import Testing
@testable import Warp

@Suite("What a run from the entry can reach")
struct ReachTests {
    // Doubles what it is sent, by sending `std.math.times`.
    private struct TwiceQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        enum Imports: Int, ImportSet {
            case times

            // MARK: - Property
            var selector: Name { "std.math.times" }

            var handing: Int { 2 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value? {
            try await question.send(.times, handing: [question[.of], .int(2)])
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure reached only through a contract is reached")
    func aDispatchReachesEveryRowAnsweringIt() async throws {
        // Given. The entry calls `app.tell`, which calls through the contract
        // and names no declaration; both types answering it are rows
        let sut = try Module(
            types: [
                "bank.Account": .record(["balance": .int]),
                "bank.Card": .record(["last": .string])
            ],
            contracts: ["app.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("app.Describable"))], returns: .string)]],
            claims: [
                "bank.Account": ["app.Describable"],
                "bank.Card": ["app.Describable"]
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("account"),
                            expression: .cast(
                                .record(["balance": .literal(.int(7))]),
                                as: .named("bank.Account"),
                                optional: false
                            )
                        )
                    ],
                    result: .call(Call(selector: "app.tell", arguments: [reference("account")]))
                ),
                "app.tell": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T", constraints: ["app.Describable"]))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(selector: "app.Describable.describe", arguments: [reference("it")]))
                ),
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("account"))
                ),
                "bank.Card.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("bank.Card"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("card"))
                ),
                "app.aside": Procedure(body: [], result: .literal(.int(1)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "app.tell", "bank.Account.describe", "bank.Card.describe"]))
        #expect(try !image.reached(from: entryName).contains("app.aside"))
    }

    @Test("a procedure a closure calls is reached, written in a body or folded into a constant")
    func aClosureIsWalkedThrough() async throws {
        // Given. One closure written in the entry's body, one folded from a
        // module constant; each calls a procedure nothing else names
        let sut = try Module(
            constants: [
                "app.folded": .closure(Procedure(body: [], result: .call(Call(selector: "app.deep"))))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("written"),
                            expression: .closure(Procedure(body: [], result: .call(Call(selector: "app.leaf"))))
                        ),
                        Statement(binding: .constant("first"), expression: .apply(reference("written"), arguments: [])),
                        Statement(binding: .constant("second"), expression: .apply(reference("app.folded"), arguments: []))
                    ],
                    result: reference("second")
                ),
                "app.leaf": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))),
                "app.aside": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(3)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "app.leaf", "app.deep"]))
        #expect(try !image.reached(from: entryName).contains("app.aside"))
    }

    @Test("a procedure a closure a variable starts out holding calls is reached")
    func aClosureAVariableStartsWithIsEntered() async throws {
        // Given. The closure is a variable's starting value, so no body
        // writes it; the entry applies what it reads out of the variable
        let sut = try Module(
            variables: [
                "app.held": .closure(Procedure(body: [], result: .call(Call(selector: "app.deep"))))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .apply(reference("app.held"), arguments: [])
                ),
                "app.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))),
                "app.aside": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(3)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "app.deep"]))
        #expect(try !image.reached(from: entryName).contains("app.aside"))
    }

    @Test("a closure a variable nobody reached reads starts out holding is not entered")
    func aVariableNoReachedBodyReadsIsNotEntered() async throws {
        // Given. `app.aside` alone reads the variable, and nothing reaches it
        let sut = try Module(
            variables: [
                "app.held": .closure(Procedure(body: [], result: .call(Call(selector: "app.deep"))))
            ],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.int(1))),
                "app.aside": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("app.held"), arguments: [])
                ),
                "app.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName) == [entryName])
    }

    @Test("what a native procedure declares it sends is reached")
    func aNativeSendIsReached() async throws {
        // Given. `app.twice` is native and sends `std.math.times`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "app.twice", arguments: [.literal(.int(2))]))
                )
            ]
        )
        let sending = try Module(
            procedures: [
                "app.twice": Procedure(
                    signature: Signature(of: TwiceQuery.self, returns: .int),
                    implementation: .query(TwiceQuery())
                )
            ]
        )

        // When
        let image = try await builder.build([sut, sending] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "app.twice", "std.math.times"]))
        #expect(try !image.reached(from: entryName).contains("std.math.plus"))
    }

    // MARK: - Public
    // MARK: - Private
}

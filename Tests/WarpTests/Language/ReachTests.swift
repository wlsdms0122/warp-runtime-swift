//
//  ReachTests.swift
//  Warp
//
//  Created by JSilver on 9/17/26.
//

import Testing
@testable import Warp

@Suite("What a run from the entry can reach")
struct ReachTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Lifecycle
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
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: [
                "bank.Account": ["app.Describable"],
                "bank.Card": ["app.Describable"]
            ],
            procedures: [
                entryName: Procedure(
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
                    result: .call(Call(receiver: reference("account"), selector: "app.tell"))
                ),
                "app.tell": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(receiver: reference("it"), selector: "app.Describable.describe"))
                ),
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("account"))
                ),
                "bank.Card.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Card"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("card"))
                ),
                "app.aside": Procedure(body: [], result: .literal(.int(1)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image.reached.isSuperset(of: [entryName, "app.tell", "bank.Account.describe", "bank.Card.describe"]))
        #expect(!image.reached.contains("app.aside"))
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
                    body: [
                        Statement(
                            binding: .constant("written"),
                            expression: .closure(Procedure(body: [], result: .call(Call(selector: "app.leaf"))))
                        ),
                        Statement(binding: .constant("first"), expression: .apply(reference("written"), arguments: [:])),
                        Statement(binding: .constant("second"), expression: .apply(reference("app.folded"), arguments: [:]))
                    ],
                    result: reference("second")
                ),
                "app.leaf": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "app.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))),
                "app.aside": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(3)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image.reached.isSuperset(of: [entryName, "app.leaf", "app.deep"]))
        #expect(!image.reached.contains("app.aside"))
    }

    @Test("what a native procedure declares it sends is reached")
    func aNativeSendIsReached() async throws {
        // Given. `app.twice` is native and sends `std.math.times`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(Call(receiver: .literal(.int(2)), selector: "app.twice"))
                )
            ]
        )
        let sending = try Module(
            procedures: [
                "app.twice": Procedure(
                    signature: Signature(of: TwiceQuery.self, receiver: .of, returns: .int),
                    implementation: .query(TwiceQuery())
                )
            ]
        )

        // When
        let image = try await builder.build([sut, sending] + Module.standard, entry: entryName)

        // Then
        #expect(image.reached.isSuperset(of: [entryName, "app.twice", "std.math.times"]))
        #expect(!image.reached.contains("std.math.plus"))
    }
}

// Doubles what it is sent, by sending `std.math.times`.
private struct TwiceQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .int) }
    }

    enum Imports: Int, ImportSet {
        case times

        var selector: Name { "std.math.times" }

        var handing: [Name] { ["value"] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.times, to: question.receiver, handing: [.int(2)])
    }

    // MARK: - Private
}

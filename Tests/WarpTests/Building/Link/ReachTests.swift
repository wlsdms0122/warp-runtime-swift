//
//  ReachTests.swift
//  WarpTests
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("What a run from the entry can reach")
struct ReachTests {
    // Doubles what it is sent, by sending `Int.times`.
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
            var selector: Name { "Int.times" }

            var handing: Int { 2 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
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
        // Given. The entry calls `App.tell`, which calls through the contract
        // and names no declaration; both types answering it are rows
        let sut = try Module(
            types: [
                "Bank.Account": .record(["balance": .int]),
                "Bank.Card": .record(["last": .string])
            ],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: [
                "Bank.Account": ["App.Describable"],
                "Bank.Card": ["App.Describable"]
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("account"),
                            expression: .cast(
                                .record(["balance": .literal(.int(7))]),
                                as: .named("Bank.Account"),
                                optional: false
                            )
                        )
                    ],
                    result: .call(Call(selector: "App.tell", arguments: [reference("account")]))
                ),
                "App.tell": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T"))],
                        returns: .string,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .call(Call(selector: "App.Describable.describe", arguments: [reference("it")]))
                ),
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("account"))
                ),
                "Bank.Card.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Card"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("card"))
                ),
                "App.aside": Procedure(body: [], result: .literal(.int(1)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "App.tell", "Bank.Account.describe", "Bank.Card.describe"]))
        #expect(try !image.reached(from: entryName).contains("App.aside"))
    }

    @Test("a procedure a closure calls is reached, written in a body or folded into a constant")
    func aClosureIsWalkedThrough() async throws {
        // Given. One closure written in the entry's body, one folded from a
        // module constant; each calls a procedure nothing else names
        let sut = try Module(
            constants: [
                "folded": .closure(Procedure(body: [], result: .call(Call(selector: "App.deep"))))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("written"),
                            expression: .closure(Procedure(body: [], result: .call(Call(selector: "App.leaf"))))
                        ),
                        Statement(binding: .constant("first"), expression: .apply(reference("written"), arguments: [])),
                        Statement(binding: .constant("second"), expression: .apply(reference("folded"), arguments: []))
                    ],
                    result: reference("second")
                ),
                "App.leaf": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1))),
                "App.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))),
                "App.aside": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(3)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "App.leaf", "App.deep"]))
        #expect(try !image.reached(from: entryName).contains("App.aside"))
    }

    @Test("a procedure a closure a variable starts out holding calls is reached")
    func aClosureAVariableStartsWithIsEntered() async throws {
        // Given. The closure is a variable's starting value, so no body
        // writes it; the entry applies what it reads out of the variable
        let sut = try Module(
            variables: [
                "held": .closure(Procedure(body: [], result: .call(Call(selector: "App.deep"))))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .apply(reference("held"), arguments: [])
                ),
                "App.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2))),
                "App.aside": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(3)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "App.deep"]))
        #expect(try !image.reached(from: entryName).contains("App.aside"))
    }

    @Test("a closure a variable nobody reached reads starts out holding is not entered")
    func aVariableNoReachedBodyReadsIsNotEntered() async throws {
        // Given. `App.aside` alone reads the variable, and nothing reaches it
        let sut = try Module(
            variables: [
                "held": .closure(Procedure(body: [], result: .call(Call(selector: "App.deep"))))
            ],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.int(1))),
                "App.aside": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("held"), arguments: [])
                ),
                "App.deep": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName) == [entryName])
    }

    @Test("what a native procedure declares it sends is reached")
    func aNativeSendIsReached() async throws {
        // Given. `App.twice` is native and sends `Int.times`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "App.twice", arguments: [.literal(.int(2))]))
                )
            ]
        )
        let sending = try Module(
            procedures: [
                "App.twice": Procedure(
                    signature: Signature(of: TwiceQuery.self, returns: .int),
                    implementation: .query(TwiceQuery())
                )
            ]
        )

        // When
        let image = try await builder.build([sut, sending] + Module.standard)

        // Then
        #expect(try image.reached(from: entryName).isSuperset(of: [entryName, "App.twice", "Int.times"]))
        #expect(try !image.reached(from: entryName).contains("Int.plus"))
    }

    @Test("names resolve across every module in the link, flat")
    func symbolsResolveAcrossModules() async throws {
        // Given. No module says anything about the others; what to link is the
        // host's statement and joining the names up is the builder's work
        let caller = try Module(
            procedures: [
                "caller": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("call"), expression: .call(Call(selector: "middle")))
                    ]
                )
            ]
        )
        let middle = try Module(
            procedures: [
                "middle": Procedure(
                    body: [
                        Statement(binding: .constant("deeper"), expression: .call(Call(selector: "leaf")))
                    ]
                )
            ]
        )
        let leaf = try Module(
            procedures: [
                "leaf": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end")))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([caller, middle, leaf])

        // Then
        #expect(try image.reached(from: "caller") == ["caller", "middle", "leaf"])
    }

    @Test("a self-recursive procedure builds once instead of forever")
    func recursiveProcedureBuildsOnce() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "loopy": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("again"), expression: .call(Call(selector: "loopy")))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut])

        // Then
        #expect(try image.reached(from: "loopy") == ["loopy"])
    }

    @Test("a procedure that calls nothing builds alone")
    func selfContainedProcedureBuilds() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "alone": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("end")))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([sut])

        // Then
        #expect(try image.reached(from: "alone") == ["alone"])
    }

    // MARK: - Public
    // MARK: - Private
}

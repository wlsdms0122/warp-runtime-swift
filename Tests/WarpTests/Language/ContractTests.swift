//
//  ContractTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// A contract: the words a value must answer. A type satisfies one by declaring
// them, a signature bounds a type parameter by it, and a body calls them
// without knowing which type it holds. The link works out which declarations
// answer, and the run reads a row out of that by the name the value wears.
@Suite("What a value is able to do")
struct ContractTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a body calls a word on a value whose type it does not know")
    func aContractCarriesAWordIntoAGenericBody() async throws {
        // Given. Two types, one contract, one body that knows neither
        let sut = try describing(
            body: [
                Statement(
                    binding: .constant("account"),
                    expression: .cast(
                        .record(["balance": .literal(.int(7))]),
                        as: .named("bank.Account"),
                        optional: false
                    )
                ),
                Statement(
                    binding: .constant("card"),
                    expression: .cast(
                        .record(["last": .literal(.string("42"))]),
                        as: .named("bank.Card"),
                        optional: false
                    )
                )
            ],
            result: .array([
                .call(Call(receiver: reference("account"), selector: "app.tell")),
                .call(Call(receiver: reference("card"), selector: "app.tell"))
            ])
        )

        // When / Then. One body, two answers, and which one ran was the value's
        #expect(try await run(sut) == .array([.string("balance 7"), .string("card 42")]))
    }

    @Test("a type that does not answer every word does not stand in the slot")
    func anUnsatisfyingTypeRefuses() throws {
        // Given. `bank.Plain` declares no `describe`
        let sut = try describing(
            types: ["bank.Plain": .record(["note": .string])],
            body: [
                Statement(
                    binding: .constant("plain"),
                    expression: .cast(
                        .record(["note": .literal(.string("x"))]),
                        as: .named("bank.Plain"),
                        optional: false
                    )
                )
            ],
            result: .call(Call(receiver: reference("plain"), selector: "app.tell"))
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("does not answer every word 'app.Describable' asks")
        }
    }

    @Test("a word sent through a contract is judged against what the contract said")
    func theContractOwnsTheJudgment() throws {
        // Given. The contract says `describe` answers a string and takes
        // nothing, so a call handing it something refuses
        let sut = try describing(
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
            result: .call(
                Call(
                    receiver: reference("account"),
                    selector: "app.Describable.describe",
                    arguments: ["style": .literal(.string("short"))]
                )
            )
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("'style', which 'app.Describable' does not name")
        }
    }

    @Test("a declaration named for a type and a word is held to the contract")
    func aMismatchedWitnessRefuses() throws {
        // Given. `bank.Account.describe` answers an int where the contract
        // writes a string
        let sut = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                entryName: Procedure(body: [], result: .literal(.null)),
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("answers int where the contract writes string")
        }
    }

    @Test("a contract asking nothing is refused, since every type answers it")
    func anEmptyContractRefuses() throws {
        // Given
        let sut = try Module(
            contracts: ["app.Anything": [:]],
            procedures: [entryName: Procedure(body: [], result: .literal(.null))]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("asks nothing, so every type satisfies it")
        }
    }

    @Test("a name is a shape or a membership or a contract, and never two of them")
    func oneNameStandsForOneThing() throws {
        // Given
        let sut = try Module(
            types: ["app.Thing": .int],
            contracts: ["app.Thing": ["describe": Signature(returns: .string)]],
            procedures: [entryName: Procedure(body: [], result: .literal(.null))]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("cannot stand for two of a shape, a membership and a contract")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Two types that describe themselves, a contract asking for it, and a
    // generic word standing between the caller and both.
    private func describing(
        types extra: [Name: TypeExpression] = [:],
        body: [Statement],
        result: Warp.Expression
    ) throws -> Module {
        try Module(
            types: [
                "bank.Account": .record(["balance": .int]),
                "bank.Card": .record(["last": .string])
            ].merging(extra) { _, added in added },
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                entryName: Procedure(body: body, result: result),
                "app.tell": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: [
                            "it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))
                        ],
                        returns: .string
                    ),
                    body: [],
                    result: .call(
                        Call(receiver: reference("it"), selector: "app.Describable.describe")
                    )
                ),
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: interpolated(
                        literal("balance "),
                        spelling(.reference([.key("of"), .key("balance")]))
                    )
                ),
                "bank.Card.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Card"))],
                        returns: .string
                    ),
                    body: [],
                    result: interpolated(
                        literal("card "),
                        spelling(.reference([.key("of"), .key("last")]))
                    )
                )
            ]
        )
    }
}

//
//  ContractTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// A contract: the words a value must answer. A document says which types
// answer one, a signature bounds a type parameter by it, and a body calls the
// words without knowing which type it holds. The link finds the declaration
// behind each claimed word, and the run reads a row out of that by the name
// the value wears.
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
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("procedures.entry.result")
                && "\(error)".contains("no document in this link says 'bank.Plain' answers it")
        }
    }

    @Test("a declaration cannot take a contract word's spelling")
    func aDeclarationCannotTakeAContractWordSpelling() throws {
        // Given. `app.Describable.describe` is both a contract's word and a
        // declaration, so a call writing that spelling has two readings
        let sut = try describing(
            types: ["bank.Plain": .record(["note": .string])],
            words: [
                "app.Describable.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("declared"))
                )
            ],
            body: [],
            result: .literal(.string("x"))
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("A contract's word and a declaration cannot take one spelling")
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
            try Builder().build([sut] + Module.standard, entry: entryName)
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
            claims: ["bank.Account": ["app.Describable"]],
            procedures: leaning(on: "bank.Account", holding: ["balance": .literal(.int(1))]).merging([
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]) { _, added in added }
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".hasPrefix("procedures.entry.result: the module at 0 in this link")
                && "\(error)".contains("declares 'bank.Account.describe', which is named for")
                && "\(error)".contains("answers int where the contract writes string")
        }
    }

    @Test("a declaration named for a type and a word answers nothing nobody claimed")
    func anUnclaimedSpellingIsAnOrdinaryWord() throws {
        // Given. One document declares `bank.Account.describe` and says
        // nothing about any contract. Another, which it never names, declares
        // a contract asking `describe` and answering a string
        let held = try Module(
            types: ["bank.Account": .record(["balance": .int])],
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
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                "app.ask": Procedure(body: [], result: .literal(.null))
            ]
        )

        // When / Then. The spelling is that document's word, so a contract
        // arriving beside it reserves nothing
        #expect(throws: Never.self) {
            try Builder().build([held, asking] + Module.standard, entry: entryName)
        }
    }

    @Test("a claim is held to every word the contract asks")
    func aClaimMissingAWordRefuses() throws {
        // Given. `bank.Plain` is said to answer, and nothing declares
        // `bank.Plain.describe`
        let sut = try Module(
            types: ["bank.Plain": .record(["note": .string])],
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: ["bank.Plain": ["app.Describable"]],
            procedures: leaning(on: "bank.Plain", holding: ["note": .literal(.string("x"))])
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("nothing in this link declares 'bank.Plain.describe'")
        }
    }

    @Test("a document declaring neither the type nor the contract may claim the pair")
    func aThirdDocumentMayClaimThePair() throws {
        // Given. Two libraries that know nothing of each other, and a third
        // that says one's type answers the other's contract and writes the
        // word that answers it.
        let charting = try Module(
            contracts: ["chart.Plottable": ["height": Signature(returns: .int)]],
            procedures: [
                "chart.draw": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: [
                            "it": Parameter(type: .parameter(name: "T", constraint: "chart.Plottable"))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(receiver: reference("it"), selector: "chart.Plottable.height"))
                )
            ]
        )
        let banking = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let adapting = try Module(
            claims: ["bank.Account": ["chart.Plottable"]],
            procedures: [
                "bank.Account.height": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("balance")])
                )
            ]
        )
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
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
                    result: .call(Call(receiver: reference("account"), selector: "chart.draw"))
                )
            ]
        )

        // When / Then
        let modules = [charting, banking, adapting, program] + Module.standard

        #expect(throws: Never.self) { try Builder().build(modules, entry: entryName) }
    }

    @Test("two documents saying one type answers one contract is one claim")
    func twoDocumentsClaimingOnePairIsOneClaim() throws {
        // Given. Two documents say the same type answers the same contract
        let held = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: ["bank.Account": ["app.Describable"]],
            procedures: [
                entryName: Procedure(body: [], result: .literal(.null)),
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("x"))
                )
            ]
        )
        let again = try Module(
            claims: ["bank.Account": ["app.Describable"]],
            procedures: ["app.ask": Procedure(body: [], result: .literal(.null))]
        )

        // When / Then. A claim holds nothing but the pair, so the second says
        // what the first said and nothing is in question.
        #expect(throws: Never.self) {
            try Builder().build([held, again] + Module.standard, entry: entryName)
        }
    }

    @Test("a claim names a type and a contract, and nothing else")
    func aClaimNamesWhatItIsAbout() throws {
        // Given. A constraint stands where the contract should
        let sut = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            constraints: ["app.Scalar": [.int, .string]],
            claims: ["bank.Account": ["app.Scalar"]],
            procedures: [entryName: Procedure(body: [], result: .literal(.null))]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("'app.Scalar' is not a contract this link declares")
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
            try Builder().build([sut] + Module.standard, entry: entryName)
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
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("cannot stand for two of a shape, a membership and a contract")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Two types that describe themselves, a contract asking for it, and a
    // generic word standing between the caller and both.
    // A word bounded by the contract, and an entry that hands the type to it.
    // A claim is held where a document leans on the pair: a list is assembled
    // from what a host was willing to supply, so one of its documents claiming
    // something the list cannot make good on refuses only the program that
    // hands that type where that contract is asked.
    private func leaning(on type: Name, holding fields: [Name: Warp.Expression]) -> [Name: Procedure] {
        [
            "app.tell": Procedure(
                signature: Signature(
                    receiver: "it",
                    parameters: [
                        "it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))
                    ],
                    returns: .string
                ),
                body: [],
                result: .call(Call(receiver: reference("it"), selector: "app.Describable.describe"))
            ),
            entryName: Procedure(
                signature: Signature(returns: .string),
                body: [
                    Statement(
                        binding: .constant("held"),
                        expression: .cast(.record(fields), as: .named(type), optional: false)
                    )
                ],
                result: .call(Call(receiver: reference("held"), selector: "app.tell"))
            )
        ]
    }

    private func describing(
        types extra: [Name: TypeExpression] = [:],
        words added: [Name: Procedure] = [:],
        body: [Statement],
        result: Warp.Expression
    ) throws -> Module {
        try Module(
            types: [
                "bank.Account": .record(["balance": .int]),
                "bank.Card": .record(["last": .string])
            ].merging(extra) { _, added in added },
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: [
                "bank.Account": ["app.Describable"],
                "bank.Card": ["app.Describable"]
            ],
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
            ].merging(added) { _, given in given }
        )
    }
}

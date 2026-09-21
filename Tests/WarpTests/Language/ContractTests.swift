//
//  ContractTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// A contract: the procedures a value must answer. A document says which types
// answer one, a signature bounds a type parameter by it, and a body calls the
// procedures without knowing which type it holds. The link finds the declaration
// behind each claimed procedure, and the run reads a row out of that by the name
// the value wears.
@Suite("What a value is able to do")
struct ContractTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a body calls a procedure on a value whose type it does not know")
    func aContractCarriesAProcedureIntoAGenericBody() async throws {
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

    @Test("a type that does not answer every procedure does not stand in the slot")
    func anUnsatisfyingTypeRefuses() async throws {
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
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("procedures.entry.result")
                && "\(error)".contains("no document in this link says 'bank.Plain' answers it")
        }
    }

    @Test("a declaration cannot take a contract procedure's spelling")
    func aDeclarationCannotTakeAContractProcedureSpelling() async throws {
        // Given. `app.Describable.describe` is both a contract's procedure and a
        // declaration, so a call writing that spelling has two readings
        let sut = try describing(
            types: ["bank.Plain": .record(["note": .string])],
            procedures: [
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
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("A contract's procedure and a declaration cannot take one spelling")
        }
    }

    @Test("a procedure sent through a contract is judged against what the contract said")
    func theContractOwnsTheJudgment() async throws {
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
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("'style', which 'app.Describable' does not name")
        }
    }

    @Test("a declaration named for a type and a procedure is held to the contract")
    func aMismatchedWitnessRefuses() async throws {
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
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".hasPrefix("procedures.entry.result: the module at 0 in this link")
                && "\(error)".contains("declares 'bank.Account.describe', which is named for")
                && "\(error)".contains("answers int where the contract writes string")
        }
    }

    @Test("a declaration named for a type and a procedure answers nothing nobody claimed")
    func anUnclaimedSpellingIsAnOrdinaryProcedure() async throws {
        // Given. One document declares `bank.Account.describe` and says
        // nothing about any contract. Another, which it never names, declares
        // a contract asking `describe` and answering a string
        let held = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
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

        // When / Then. The spelling is that document's procedure, so a contract
        // arriving beside it reserves nothing
        await #expect(throws: Never.self) {
            try await Builder().build([held, asking] + Module.standard, entry: entryName)
        }
    }

    @Test("a claim is held to every procedure the contract asks")
    func aClaimMissingAProcedureRefuses() async throws {
        // Given. `bank.Plain` is said to answer, and nothing declares
        // `bank.Plain.describe`
        let sut = try Module(
            types: ["bank.Plain": .record(["note": .string])],
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: ["bank.Plain": ["app.Describable"]],
            procedures: leaning(on: "bank.Plain", holding: ["note": .literal(.string("x"))])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("nothing in this link declares 'bank.Plain.describe'")
        }
    }

    @Test("a document declaring neither the type nor the contract may claim the pair")
    func aThirdDocumentMayClaimThePair() async throws {
        // Given. Two libraries that know nothing of each other, and a third
        // that says one's type answers the other's contract and writes the
        // procedure that answers it.
        let charting = try Module(
            contracts: ["chart.Plottable": ["height": Signature(returns: .int)]],
            procedures: [
                "chart.draw": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: [
                            "it": Parameter(type: .parameter(name: "T", constraints: ["chart.Plottable"]))
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
                    access: .public,
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

        await #expect(throws: Never.self) { try await Builder().build(modules, entry: entryName) }
    }

    @Test("two documents saying one type answers one contract is one claim")
    func twoDocumentsClaimingOnePairIsOneClaim() async throws {
        // Given. Two documents say the same type answers the same contract
        let held = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: ["bank.Account": ["app.Describable"]],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
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
        await #expect(throws: Never.self) {
            try await Builder().build([held, again] + Module.standard, entry: entryName)
        }
    }

    @Test("a claim names a type and a contract, and nothing else")
    func aClaimNamesWhatItIsAbout() async throws {
        // Given. A constraint stands where the contract should
        let sut = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            constraints: ["app.Scalar": [.int, .string]],
            claims: ["bank.Account": ["app.Scalar"]],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("'app.Scalar' is not a contract this link declares")
        }
    }

    @Test("a contract asking nothing is refused, since every type answers it")
    func anEmptyContractRefuses() async throws {
        // Given
        let sut = try Module(
            contracts: ["app.Anything": [:] as [Name: ContractProcedure]],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("asks nothing, so every type satisfies it")
        }
    }

    @Test("a name is a type or a membership or a contract, and never two of them")
    func oneNameStandsForOneThing() async throws {
        // Given
        let sut = try Module(
            types: ["app.Thing": .int],
            contracts: ["app.Thing": ["describe": Signature(returns: .string)]],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("cannot be a type, a membership and a contract at once")
        }
    }

    @Test("a contract's procedure stands as an operand where the contract asks const, and is refused where it asks nothing", arguments: [true, false])
    func aContractCallStandsAsAnOperand(asked: Bool) async throws {
        // Given. An operand answers without running, and the build refuses one
        // that calls a declaration answering only by running. A call through
        // a contract reads as the contract asked of every declaration
        // answering it: `const`, and the operand stands; nothing, and it may
        // run, so it is refused.
        let sut = try Module(
            imports: ["std.text.uppercased"],
            types: ["bank.Account": .record(["balance": .int])],
            contracts: ["app.Describable": ["describe": ContractProcedure(signature: Signature(returns: .string), constness: asked ? .const : .unstated)]],
            claims: ["bank.Account": ["app.Describable"]],
            procedures: [
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                ),
                "app.tell": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: [
                            "it": Parameter(type: .parameter(name: "T", constraints: ["app.Describable"]))
                        ],
                        returns: .string
                    ),
                    body: [],
                    result: .call(
                        Call(
                            receiver: .call(
                                Call(receiver: reference("it"), selector: "app.Describable.describe")
                            ),
                            selector: "std.text.uppercased"
                        )
                    )
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            binding: .constant("held"),
                            expression: .cast(
                                .record(["balance": .literal(.int(1))]),
                                as: .named("bank.Account"),
                                optional: false
                            )
                        )
                    ],
                    result: .call(Call(receiver: reference("held"), selector: "app.tell"))
                )
            ]
        )

        // When / Then
        if asked {
            #expect(try await run([sut]) == .string("AN ACCOUNT"))
        } else {
            await #expect(throws: BuildError.self) {
                try await run([sut])
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Two types that describe themselves, a contract asking for it, and a
    // generic procedure standing between the caller and both.
    // A procedure bounded by the contract, and an entry that hands the type to it.
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
                        "it": Parameter(type: .parameter(name: "T", constraints: ["app.Describable"]))
                    ],
                    returns: .string
                ),
                body: [],
                result: .call(Call(receiver: reference("it"), selector: "app.Describable.describe"))
            ),
            entryName: Procedure(
                access: .public,
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
        procedures added: [Name: Procedure] = [:],
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
                entryName: Procedure(access: .public, body: body, result: result),
                "app.tell": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: [
                            "it": Parameter(type: .parameter(name: "T", constraints: ["app.Describable"]))
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

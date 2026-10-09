//
//  ContractTests.swift
//  WarpTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// A contract: the procedures a value's type must answer. A document says which
// types answer one, a signature bounds a type parameter by it, and a body calls
// the procedures without knowing which type it holds. The link finds the
// declaration behind each claimed procedure, and the run reads a row out of
// that by the type the value is an instance of.
@Suite("What a value is able to do")
struct ContractTests {
    // MARK: - Property
    // MARK: - Initializer
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
                        as: .named("Bank.Account"),
                        optional: false
                    )
                ),
                Statement(
                    binding: .constant("card"),
                    expression: .cast(
                        .record(["last": .literal(.string("42"))]),
                        as: .named("Bank.Card"),
                        optional: false
                    )
                )
            ],
            result: .array([
                .call(Call(selector: "App.tell", arguments: [reference("account")])),
                .call(Call(selector: "App.tell", arguments: [reference("card")]))
            ])
        )

        // When / Then. One body, two answers, and which one ran was the value's
        #expect(try await run(sut) == .array([.string("balance 7"), .string("card 42")]))
    }

    @Test("a type that does not answer every procedure does not stand in the slot")
    func anUnsatisfyingTypeRefuses() async throws {
        // Given. `Bank.Plain` declares no `describe`
        let sut = try describing(
            types: ["Bank.Plain": .record(["note": .string])],
            body: [
                Statement(
                    binding: .constant("plain"),
                    expression: .cast(
                        .record(["note": .literal(.string("x"))]),
                        as: .named("Bank.Plain"),
                        optional: false
                    )
                )
            ],
            result: .call(Call(selector: "App.tell", arguments: [reference("plain")]))
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("procedures.entry.result")
                && "\(error)".contains("no document in this link says 'Bank.Plain' answers it")
        }
    }

    @Test("a declaration cannot take a contract procedure's spelling")
    func aDeclarationCannotTakeAContractProcedureSpelling() async throws {
        // Given. `App.Describable.describe` is both a contract's procedure and a
        // declaration, so a call writing that spelling has two readings
        let sut = try describing(
            procedures: [
                "App.Describable.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
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
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("A contract's procedure and a declaration cannot take one spelling")
        }
    }

    @Test("a procedure sent through a contract is judged against what the contract said")
    func theContractOwnsTheJudgment() async throws {
        // Given. The contract says `describe` answers a string and takes
        // nothing but the value it is sent through, so a call handing it
        // something more refuses
        let sut = try describing(
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
            result: .call(
                Call(
                    selector: "App.Describable.describe",
                    arguments: [reference("account"), .literal(.string("short"))]
                )
            )
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("sending 'App.Describable.describe' with 2 arguments, and it takes 1")
        }
    }

    @Test("an argument sent through a contract passes the gates an argument sent to a declaration does")
    func aContractCallHoldsItsArgumentsAsADeclaredCallDoes() async throws {
        // Given. `App.Sized.size` takes a whole number, and `App.Bumping.bump`
        // takes a variable in place
        func sending(_ contract: Name, _ procedure: Name, _ parameter: TypeExpression, _ argument: Warp.Expression) throws -> Module {
            try Module(
                types: ["Bank.Account": .record(["balance": .int])],
                contracts: [contract: [procedure: Signature(parameters: [Parameter(name: "of", type: .selfType), Parameter(name: "n", type: parameter)], returns: .int)]],
                claims: ["Bank.Account": [contract]],
                procedures: [
                    Name(stringLiteral: "Bank.Account.\(procedure.spelling)"): Procedure(
                        signature: Signature(parameters: [Parameter(name: "of", type: .named("Bank.Account")), Parameter(name: "n", type: parameter)], returns: .int),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [
                            Statement(
                                binding: .constant("account"),
                                expression: .cast(.record(["balance": .literal(.int(7))]), as: .named("Bank.Account"), optional: false)
                            )
                        ],
                        result: .call(
                            Call(
                                selector: Name(stringLiteral: "\(contract.spelling).\(procedure.spelling)"),
                                arguments: [reference("account"), argument]
                            )
                        )
                    )
                ]
            )
        }

        // When
        let mistyped = await #expect(throws: BuildError.self) {
            try await Builder().build([try sending("App.Sized", "size", .int, .literal(.string("ninety-nine")))] + Module.standard)
        }
        let inPlace = await #expect(throws: BuildError.self) {
            try await Builder().build([try sending("App.Bumping", "bump", .inout(.int), .literal(.int(3)))] + Module.standard)
        }

        // Then. Each refused where the argument is written, for what the author wrote
        #expect(mistyped?.message == "sending 'App.Sized.size' with n, which holds String where Int is declared")
        #expect(mistyped?.place?.rendered == "procedures.\(entryName.spelling).result.arguments[1]")
        #expect(inPlace?.message.hasPrefix("hands this argument in place") == true)
        #expect(inPlace?.place?.rendered == "procedures.\(entryName.spelling).result.arguments[1]")
    }

    @Test("a declaration named for a type and a procedure is held to the contract")
    func aMismatchedWitnessRefuses() async throws {
        // Given. `Bank.Account.describe` answers an int where the contract
        // writes a string
        let sut = try Module(
            types: ["Bank.Account": .record(["balance": .int])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: leaning(on: "Bank.Account", holding: ["balance": .literal(.int(1))]).merging([
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]) { _, added in added }
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".hasPrefix("procedures.entry.result: the module at 0 in this link")
                && "\(error)".contains("declares 'Bank.Account.describe', which is named for")
                && "\(error)".contains("answers Int where the contract writes String")
        }
    }

    @Test("a declaration named for a type and a procedure answers nothing nobody claimed")
    func anUnclaimedSpellingIsAnOrdinaryProcedure() async throws {
        // Given. One document declares `Bank.Account.describe` and says
        // nothing about any contract. Another, which it never names, declares
        // a contract asking `describe` and answering a string
        let held = try Module(
            types: ["Bank.Account": .record(["balance": .int])],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.ask": Procedure(body: [], result: .literal(.null))
            ]
        )

        // When / Then. The spelling is that document's procedure, so a contract
        // arriving beside it reserves nothing
        await #expect(throws: Never.self) {
            try await Builder().build([held, asking] + Module.standard)
        }
    }

    @Test("a claim is held to every procedure the contract asks")
    func aClaimMissingAProcedureRefuses() async throws {
        // Given. `Bank.Plain` is said to answer, and nothing declares
        // `Bank.Plain.describe`
        let sut = try Module(
            types: ["Bank.Plain": .record(["note": .string])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: ["Bank.Plain": ["App.Describable"]],
            procedures: leaning(on: "Bank.Plain", holding: ["note": .literal(.string("x"))])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("nothing in this link declares 'Bank.Plain.describe'")
        }
    }

    @Test("a document declaring neither the type nor the contract may claim the pair")
    func aThirdDocumentMayClaimThePair() async throws {
        // Given. Two libraries that know nothing of each other, and a third
        // that says one's type answers the other's contract and writes the
        // procedure that answers it.
        let charting = try Module(
            contracts: ["Chart.Plottable": ["height": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .int)]],
            procedures: [
                "Chart.draw": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "it", type: .parameter(name: "T"))
                        ],
                        returns: .int,
                        bounds: ["T": ["Chart.Plottable"]]
                    ),
                    body: [],
                    result: .call(Call(selector: "Chart.Plottable.height", arguments: [reference("it")]))
                )
            ]
        )
        let banking = try Module(
            types: ["Bank.Account": .record(["balance": .int])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let adapting = try Module(
            claims: ["Bank.Account": ["Chart.Plottable"]],
            procedures: [
                "Bank.Account.height": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
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
                                as: .named("Bank.Account"),
                                optional: false
                            )
                        )
                    ],
                    result: .call(Call(selector: "Chart.draw", arguments: [reference("account")]))
                )
            ]
        )

        // When / Then
        let modules = [charting, banking, adapting, program] + Module.standard

        await #expect(throws: Never.self) { try await Builder().build(modules) }
    }

    @Test("two documents saying one type answers one contract is one claim")
    func twoDocumentsClaimingOnePairIsOneClaim() async throws {
        // Given. Two documents say the same type answers the same contract
        let held = try Module(
            types: ["Bank.Account": .record(["balance": .int])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("x"))
                )
            ]
        )
        let again = try Module(
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: ["App.ask": Procedure(body: [], result: .literal(.null))]
        )

        // When / Then. A claim holds nothing but the pair, so the second says
        // what the first said and nothing is in question.
        await #expect(throws: Never.self) {
            try await Builder().build([held, again] + Module.standard)
        }
    }

    @Test("a claim names a type and a contract, and nothing else")
    func aClaimNamesWhatItIsAbout() async throws {
        // Given. A type stands where the contract should
        let sut = try Module(
            types: ["Bank.Account": .record(["balance": .int]), "App.Scalar": .int],
            claims: ["Bank.Account": ["App.Scalar"]],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("'App.Scalar' is not a contract this link declares")
        }
    }

    @Test("a claim about Array answered for a bounded element names the element as whatever a list holds")
    func aClaimAboutArrayNamesItsElementPlainly() async throws {
        // Given. A list's element is whatever it holds, which a bound on the
        // declaration's own parameter does not take
        let sut = try Module(
            contracts: ["App.Sortable": ["sort": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .int)]],
            claims: ["Array": ["App.Sortable"]],
            procedures: [
                "Array.sort": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .array(.parameter(name: "T")))],
                        returns: .int,
                        bounds: ["T": ["Standard.Comparable"]]
                    ),
                    body: [],
                    result: .literal(.int(0))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "App.Sortable.sort", arguments: [.array([.literal(.int(1))])]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("reads 'T' as whatever element a value of 'Array' holds") && !"\(error)".contains("Self.Element")
        }
    }

    @Test("a contract asking nothing is answered by the types claimed for it alone")
    func anEmptyContractIsAMark() async throws {
        // Given. `Int` is claimed for a contract asking nothing, and `String` is not.
        let module = { (handed: Warp.Expression) in
            try Module(
                contracts: ["App.Marked": [:] as [Name: ContractProcedure]],
                claims: ["Int": ["App.Marked"]],
                procedures: [
                    "App.take": Procedure(
                        signature: Signature(parameters: [Parameter(name: "it", type: .named("App.Marked"))], returns: .int),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "App.take", arguments: [handed]))
                    )
                ]
            )
        }

        // When
        let image = try await Builder().build([try module(.literal(.int(1)))] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .int(1))

        await #expect {
            try await Builder().build([try module(.literal(.string("x")))] + Module.standard)
        } throws: { error in
            "\(error)".contains("no document in this link says 'String' answers it")
        }
    }

    @Test("a name is a type or a contract, and never both")
    func oneNameStandsForOneThing() async throws {
        // Given
        let sut = try Module(
            types: ["App.Thing": .int],
            contracts: ["App.Thing": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("cannot stand for a type and a contract at once")
        }
    }

    @Test("a contract's procedure asking const stands as an operand")
    func aConstContractCallStandsAsAnOperand() async throws {
        // Given. An operand answers without running, and a call through a
        // contract reads as the contract asked of every declaration answering
        // it: `const`, and the operand stands
        let sut = try operand(asking: .const)

        // When / Then
        #expect(try await run([sut]) == .string("AN ACCOUNT"))
    }

    @Test("a contract's procedure asking nothing is refused as an operand")
    func anUnstatedContractCallIsRefusedAsAnOperand() async throws {
        // Given. A contract's procedure asking nothing may run, and an operand
        // is read rather than run
        let sut = try operand(asking: .unstated)

        // When / Then
        await #expect {
            try await run([sut])
        } throws: { error in
            error is BuildError
                && "\(error)".contains("reads 'App.Describable.describe', which answers only by running")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A contract whose procedure asks this constness, and an entry calling
    // through it inside an operand.
    private func operand(asking constness: Constness) throws -> Module {
        try Module(
            imports: ["Standard.Text.uppercased"],
            types: ["Bank.Account": .record(["balance": .int])],
            contracts: ["App.Describable": ["describe": ContractProcedure(signature: Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string), constness: constness)]],
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: [
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                ),
                "App.tell": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "it", type: .parameter(name: "T"))
                        ],
                        returns: .string,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .call(
                        Call(
                            selector: "Standard.Text.uppercased",
                            arguments: [
                                .call(
                                    Call(selector: "App.Describable.describe", arguments: [reference("it")])
                                )
                            ]
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
                                as: .named("Bank.Account"),
                                optional: false
                            )
                        )
                    ],
                    result: .call(Call(selector: "App.tell", arguments: [reference("held")]))
                )
            ]
        )
    }

    // A procedure bounded by the contract, and an entry that hands the type to
    // it. A claim is held where a document leans on the pair, so a claim the
    // list cannot make good on refuses only the program that hands that type
    // where that contract is asked.
    private func leaning(on type: Name, holding fields: [Name: Warp.Expression]) -> [Name: Procedure] {
        [
            "App.tell": Procedure(
                signature: Signature(
                    parameters: [
                        Parameter(name: "it", type: .parameter(name: "T"))
                    ],
                    returns: .string,
                    bounds: ["T": ["App.Describable"]]
                ),
                body: [],
                result: .call(Call(selector: "App.Describable.describe", arguments: [reference("it")]))
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
                result: .call(Call(selector: "App.tell", arguments: [reference("held")]))
            )
        ]
    }

    // Two types that describe themselves, a contract asking for it, and a
    // generic procedure standing between the caller and both.
    private func describing(
        types extra: [Name: TypeExpression] = [:],
        procedures added: [Name: Procedure] = [:],
        body: Body,
        result: Warp.Expression
    ) throws -> Module {
        try Module(
            types: [
                "Bank.Account": .record(["balance": .int]),
                "Bank.Card": .record(["last": .string])
            ].merging(extra) { _, added in added },
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: [
                "Bank.Account": ["App.Describable"],
                "Bank.Card": ["App.Describable"]
            ],
            procedures: [
                entryName: Procedure(access: .public, body: body, result: result),
                "App.tell": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "it", type: .parameter(name: "T"))
                        ],
                        returns: .string,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .call(
                        Call(selector: "App.Describable.describe", arguments: [reference("it")])
                    )
                ),
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: interpolated(
                        literal("balance "),
                        spelling(.reference([.key("of"), .key("balance")]))
                    )
                ),
                "Bank.Card.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Card"))],
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

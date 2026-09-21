//
//  UnheldClaimTests.swift
//  Warp
//

import Testing
@testable import Warp

@Suite("A claim nobody leans on refuses nobody")
struct UnheldClaimTests {
    private let entryName: Name = "app.main"

    @Test("a claim with no procedure behind it refuses only what leans on it")
    func anUnheldClaimRefusesOnlyWhatLeansOnIt() async throws {
        // Given. A contract, a type, and a claim about the two with no procedure
        // anywhere to answer it. The program names both for its own reasons
        // and hands the type nowhere.
        // A contract and a type, both named by the program for their own sake.
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                "app.tell": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraints: ["app.Describable"]))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(receiver: .reference([.key("it")]), selector: "app.Describable.describe"))
                )
            ]
        )
        let typed = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // Claims the pair and declares no witness at all.
        let broken = try Module(
            claims: ["bank.Account": ["app.Describable"]],
            procedures: ["other.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // Names both, and leans on neither: it never hands an Account to tell.
        let program = try Module(
            procedures: [
                "app.mine": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraints: ["app.Describable"]))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(receiver: .reference([.key("it")]), selector: "app.tell"))
                ),
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
                        ),
                    ],
                    result: .reference([.key("account"), .key("balance")])
                )
            ]
        )

        // When
        let catalogue = try Catalogue([asking, typed, broken] + Module.standard)
        let closed = catalogue.closing([program])

        // Then. The claim stands in the link and puts its type under no
        // contract, and the program that never handed the type where the
        // contract is asked is not the one to hear about it.
        #expect(closed.contains { module in module.claims.isEmpty == false })
        await #expect(throws: Never.self) { try await Builder().build(closed, entry: entryName) }
    }

    @Test("a good claim beside an unheld one in the same document")
    func aGoodClaimBesideAnUnheldOne() async throws {
        // Given. One document claiming two pairs, one of them with no procedure
        // behind it, and a program leaning on the other.
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
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
                        Call(receiver: .reference([.key("it")]), selector: "app.Describable.describe")
                    )
                )
            ]
        )
        let typed = try Module(
            types: [
                "bank.Account": .record(["balance": .int]),
                "bank.Plain": .record(["note": .string])
            ],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let adapting = try Module(
            claims: [
                "bank.Account": ["app.Describable"],
                "bank.Plain": ["app.Describable"]
            ],
            procedures: [
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
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
                    result: .call(Call(receiver: .reference([.key("account")]), selector: "app.tell"))
                )
            ]
        )

        // When
        let catalogue = try Catalogue([asking, typed, adapting] + Module.standard)
        let closed = catalogue.closing([program])

        // Then. The pair the program leans on is answered, and the one beside
        // it that nothing can answer refuses nobody.
        await #expect(throws: Never.self) { try await Builder().build(closed, entry: entryName) }
    }

    @Test("an unheld claim refuses at the call that leaned on it")
    func anUnheldClaimRefusesAtTheLeaningCall() async throws {
        // Given. The claim in one document with no procedure behind it, and the
        // program that hands the type in another.
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
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
                        Call(receiver: .reference([.key("it")]), selector: "app.Describable.describe")
                    )
                )
            ]
        )
        let typed = try Module(
            types: ["bank.Plain": .record(["note": .string])],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let claims = try Module(
            claims: ["bank.Plain": ["app.Describable"]],
            procedures: ["glue.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let program = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
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
                    result: .call(Call(receiver: .reference([.key("plain")]), selector: "app.tell"))
                )
            ]
        )

        // When / Then. The refusal says why the claim did not hold and stands
        // where the type was handed over, which is the document an author is
        // reading.
        await #expect {
            try await Builder().build([asking, typed, claims, program] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("procedures.app.main.result")
                && "\(error)".contains("nothing in this link declares 'bank.Plain.describe'")
        }
    }

    @Test("a constant folded before the claim arrives is answered by the list")
    func aFoldedConstantIsAnsweredByTheList() async throws {
        // Given. A procedure bounded by a contract that answers without running, a
        // constant handing it a type, and the claim in a document the program
        // never names.
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                "app.count": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: [
                            "it": Parameter(type: .parameter(name: "T", constraints: ["app.Describable"]))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )
        let typed = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            procedures: [
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let claims = try Module(
            claims: ["bank.Account": ["app.Describable"]],
            procedures: ["glue.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let program = try Module(
            constants: [
                "app.counted": .call(
                    Call(
                        receiver: .cast(
                            .record(["balance": .literal(.int(7))]),
                            as: .named("bank.Account"),
                            optional: false
                        ),
                        selector: "app.count"
                    )
                )
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("app.counted")])
                )
            ]
        )

        // When / Then. Folding runs where the document is compiled, against
        // the claims of what stood before it, and the claim is not among them.
        // The pair is written down there and the list answers, so the order
        // the caller listed them in decides nothing.
        let modules = [typed, asking, program, claims] + Module.standard
        var compiled: [Compiled] = []

        for origin in try ModuleGraph(modules).standing {
            compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
        }

        #expect(throws: Never.self) { try Builder().link(compiled, entry: entryName, supplying: Supplying(Module.standard)) }
        await #expect(throws: Never.self) { try await Builder().build(modules, entry: entryName) }
    }
}

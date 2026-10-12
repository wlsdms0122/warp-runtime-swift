//
//  UnheldClaimTests.swift
//  WarpTests
//
//  Created by JSilver on 9/10/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A claim nobody leans on refuses nobody")
struct UnheldClaimTests {
    // MARK: - Property
    private let main: Name = "App.main"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a claim with no procedure behind it refuses only what leans on it")
    func anUnheldClaimRefusesOnlyWhatLeansOnIt() async throws {
        // Given. A contract, a type, and a claim about the two with no procedure
        // anywhere to answer it. The program names both and hands the type
        // nowhere.
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.tell": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T"))],
                        returns: .string,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .call(Call(selector: "App.Describable.describe", arguments: [.reference([.name("it")])]))
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Account": .record(["balance": .int])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // Claims the pair and declares no witness at all.
        let broken = try Module(
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: ["Other.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // Names both, and leans on neither: it never hands an Account to tell.
        let program = try Module(
            procedures: [
                "App.mine": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T"))],
                        returns: .string,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .call(Call(selector: "App.tell", arguments: [.reference([.name("it")])]))
                ),
                main: Procedure(
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
                    result: .reference([.name("account"), .name("balance")])
                )
            ]
        )
        let linked = [asking, typed, broken, program] + Module.standard

        // When / Then. The claim stands in the link and puts its type under no
        // contract, and the program that never handed the type where the
        // contract is asked is not the one to hear about it.
        await #expect(throws: Never.self) { try await Builder().build(linked) }
    }

    @Test("a good claim beside an unheld one in the same document")
    func aGoodClaimBesideAnUnheldOne() async throws {
        // Given. One document claiming two pairs, one of them with no procedure
        // behind it, and a program leaning on the other.
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
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
                        Call(selector: "App.Describable.describe", arguments: [.reference([.name("it")])])
                    )
                )
            ]
        )
        let typed = try Module(
            types: [
                "Bank.Account": .record(["balance": .int]),
                "Bank.Plain": .record(["note": .string])
            ],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let adapting = try Module(
            claims: [
                "Bank.Account": ["App.Describable"],
                "Bank.Plain": ["App.Describable"]
            ],
            procedures: [
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let program = try Module(
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
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
                    result: .call(Call(selector: "App.tell", arguments: [.reference([.name("account")])]))
                )
            ]
        )
        let linked = [asking, typed, adapting, program] + Module.standard

        // When / Then. The pair the program leans on is answered, and the one
        // beside it that nothing can answer refuses nobody.
        await #expect(throws: Never.self) { try await Builder().build(linked) }
    }

    @Test("an unheld claim refuses at the call that leaned on it")
    func anUnheldClaimRefusesAtTheLeaningCall() async throws {
        // Given. The claim in one document with no procedure behind it, and the
        // program that hands the type in another.
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
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
                        Call(selector: "App.Describable.describe", arguments: [.reference([.name("it")])])
                    )
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Plain": .record(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let claims = try Module(
            claims: ["Bank.Plain": ["App.Describable"]],
            procedures: ["Glue.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let program = try Module(
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
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
                    result: .call(Call(selector: "App.tell", arguments: [.reference([.name("plain")])]))
                )
            ]
        )

        // When / Then. The refusal says why the claim did not hold and stands
        // where the type was handed over, which is the document an author is
        // reading.
        await #expect {
            try await Builder().build([asking, typed, claims, program] + Module.standard)
        } throws: { error in
            "\(error)".contains("procedures.App.main.result")
                && "\(error)".contains("nothing in this link declares 'Bank.Plain.describe'")
        }
    }

    @Test("a constant folded before the claim arrives is answered by the list")
    func aFoldedConstantIsAnsweredByTheList() async throws {
        // Given. A procedure bounded by a contract that answers without running, a
        // constant handing it a type, and the claim in a document the program
        // never names.
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.count": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "it", type: .parameter(name: "T"))
                        ],
                        returns: .int,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Account": .record(["balance": .int])],
            procedures: [
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )
        let claims = try Module(
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: ["Glue.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let program = try Module(
            constants: [
                "counted": .call(
                    Call(
                        selector: "App.count",
                        arguments: [
                            .cast(
                                .record(["balance": .literal(.int(7))]),
                                as: .named("Bank.Account"),
                                optional: false
                            )
                        ]
                    )
                )
            ],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.name("counted")])
                )
            ]
        )

        // When / Then. Folding runs where the document is compiled, against
        // the claims of what stood before it, and the claim is not among them.
        // The pair is written down there and the list answers, so the order
        // the host listed them in decides nothing.
        let modules = [typed, asking, program, claims] + Module.standard
        var compiled: [Compiled] = []

        for origin in try ModuleGraph(modules).standing {
            compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
        }

        #expect(throws: Never.self) { try Builder().link(compiled, supplying: Supplying(Module.standard)) }
        await #expect(throws: Never.self) { try await Builder().build(modules) }
    }

    // MARK: - Public
    // MARK: - Private
}

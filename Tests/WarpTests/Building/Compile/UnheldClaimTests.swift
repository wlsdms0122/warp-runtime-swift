//
//  UnheldClaimTests.swift
//  WarpTests
//
//  Created by JSilver on 9/10/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A claim is held where it is written")
struct UnheldClaimTests {
    // MARK: - Property
    private let main: Name = "App.main"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a claim with no procedure behind it refuses at the claim though nothing asks it")
    func anUnheldClaimRefusesAtTheClaim() async throws {
        // Given. A contract, a type, and a claim about the two with no procedure
        // anywhere to satisfy it. The program names both and hands the type
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
                    body: [returning(.call(Call(selector: "App.Describable.describe", arguments: [.reference([.name("it")])])))]
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Account": .struct(["balance": .int])],
            procedures: ["Bank.nothing": Procedure(body: [])]
        )
        // Claims the pair and declares no witness at all.
        let broken = try Module(
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: ["Other.nothing": Procedure(body: [])]
        )
        // Names both, and asks neither: it never hands an Account to tell.
        let program = try Module(
            procedures: [
                "App.mine": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T"))],
                        returns: .string,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [returning(.call(Call(selector: "App.tell", arguments: [.reference([.name("it")])])))]
                ),
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .constant("account"),
                            expression: .cast(
                                .struct(["balance": .literal(.int(7))]),
                                as: .named("Bank.Account"),
                                optional: false
                            )
                        ),
                        returning(.reference([.name("account"), .name("balance")]))
                    ]
                )
            ]
        )
        let linked = [asking, typed, broken, program] + Module.standard

        // When / Then. The claim is judged where it is written, so the
        // document making it hears about it, whoever asks the contract.
        await #expect {
            try await Builder().build(linked)
        } throws: { error in
            "\(error)".contains("extensions.Bank.Account.satisfies")
                && "\(error)".contains("nothing it stands on gives 'Bank.Account' the member 'describe'")
        }
    }

    @Test("an unheld claim refuses beside a good one in the same document")
    func anUnheldClaimRefusesBesideAGoodOne() async throws {
        // Given. One document claiming two pairs, one of them with no procedure
        // behind it, and a program asking the other.
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
                    body: [
                        returning(.call(
                            Call(selector: "App.Describable.describe", arguments: [.reference([.name("it")])])
                        ))
                    ]
                )
            ]
        )
        let typed = try Module(
            types: [
                "Bank.Account": .struct(["balance": .int]),
                "Bank.Plain": .struct(["note": .string])
            ],
            procedures: ["Bank.nothing": Procedure(body: [])]
        )
        let adapting = try Module(
            claims: [
                "Bank.Account": ["App.Describable"],
                "Bank.Plain": ["App.Describable"]
            ],
            members: ["Bank.Account": ["describe"]],
            procedures: [
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [returning(.literal(.string("an account")))]
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
                                .struct(["balance": .literal(.int(7))]),
                                as: .named("Bank.Account"),
                                optional: false
                            )
                        ),
                        returning(.call(Call(selector: "App.tell", arguments: [.reference([.name("account")])])))
                    ]
                )
            ]
        )
        let linked = [asking, typed, adapting, program] + Module.standard

        // When / Then. The pair the program asks is satisfied, and the one
        // beside it that nothing can satisfy refuses at itself.
        await #expect {
            try await Builder().build(linked)
        } throws: { error in
            "\(error)".contains("extensions.Bank.Plain.satisfies")
        }
    }

    @Test("an unheld claim a program imports refuses at the claim")
    func anImportedUnheldClaimRefusesAtTheClaim() async throws {
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
                    body: [
                        returning(.call(
                            Call(selector: "App.Describable.describe", arguments: [.reference([.name("it")])])
                        ))
                    ]
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Plain": .struct(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [])]
        )
        let claims = try Module(
            claims: ["Bank.Plain": ["App.Describable"]],
            procedures: ["Glue.nothing": Procedure(body: [])]
        )
        let program = try Module(
            importedClaims: [ClaimPair("Bank.Plain", "App.Describable")],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            binding: .constant("plain"),
                            expression: .cast(
                                .struct(["note": .literal(.string("x"))]),
                                as: .named("Bank.Plain"),
                                optional: false
                            )
                        ),
                        returning(.call(Call(selector: "App.tell", arguments: [.reference([.name("plain")])])))
                    ]
                )
            ]
        )

        // When / Then. The refusal says why the claim did not hold and stands
        // where the claim was written, whoever stands on it.
        await #expect {
            try await Builder().build([asking, typed, claims, program] + Module.standard)
        } throws: { error in
            "\(error)".contains("extensions.Bank.Plain.satisfies")
                && "\(error)".contains("nothing it stands on gives 'Bank.Plain' the member 'describe'")
        }
    }

    @Test("a constant folds through a claim its document imports, however the documents were compiled")
    func aFoldedConstantStandsOnAnImportedClaim() async throws {
        // Given. A const procedure bounded by a contract, a
        // constant handing it a type, and the claim in a document the program
        // names nothing of and imports the claim of.
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.count": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "it", type: .parameter(name: "T"))
                        ],
                        returns: .int,
                        constness: .const,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [returning(.literal(.int(1)))]
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Account": .struct(["balance": .int])],
            members: ["Bank.Account": ["describe"]],
            procedures: [
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [returning(.literal(.string("an account")))]
                )
            ]
        )
        let claims = try Module(
            claims: ["Bank.Account": ["App.Describable"]],
            procedures: ["Glue.nothing": Procedure(body: [])]
        )
        let program = try Module(
            importedClaims: [ClaimPair("Bank.Account", "App.Describable")],
            constants: [
                "counted": .call(
                    Call(
                        selector: "App.count",
                        arguments: [
                            .cast(
                                .struct(["balance": .literal(.int(7))]),
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
                    body: [returning(.reference([.name("counted")]))]
                )
            ]
        )

        // When / Then. Folding runs where the document is compiled, against
        // the claims within its reach, which the import puts the claim among,
        // so the order the host listed them in decides nothing.
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

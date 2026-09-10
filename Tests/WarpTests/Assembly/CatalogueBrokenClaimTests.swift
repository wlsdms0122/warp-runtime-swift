//
//  CatalogueBrokenClaimTests.swift
//  Warp
//

import Testing
@testable import Warp

@Suite("A catalogue supplies only a claim it can answer")
struct CatalogueBrokenClaimTests {
    private let entryName: Name = "app.main"

    @Test("a claim the catalogue cannot answer is left where it stands")
    func aClaimTheCatalogueCannotAnswerIsLeftAlone() throws {
        // Given. A contract, a type, and a claim about the two with no word
        // anywhere to answer it. The program names both for its own reasons
        // and hands the type nowhere.
        // A contract and a type, both named by the program for their own sake.
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                "app.tell": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))],
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
            claiming: ["bank.Account": ["app.Describable"]],
            procedures: ["other.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // Names both, and leans on neither: it never hands an Account to tell.
        let program = try Module(
            procedures: [
                "app.mine": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(receiver: .reference([.key("it")]), selector: "app.tell"))
                ),
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
                        ),
                    ],
                    result: .reference([.key("account"), .key("balance")])
                )
            ]
        )

        // When
        let catalogue = try Catalogue([asking, typed, broken] + Module.standard)
        let closed = catalogue.closing([program])

        // Then. A claim in the link is held to every word its contract asks,
        // so one nothing can answer would refuse a program that never leaned
        // on the pair.
        #expect(closed.allSatisfy { module in module.claiming.isEmpty })
        #expect(throws: Never.self) { try Linker().link(closed, entry: entryName) }
    }
}

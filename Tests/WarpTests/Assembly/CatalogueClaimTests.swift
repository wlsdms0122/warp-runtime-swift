//
//  CatalogueClaimTests.swift
//  Warp
//

import Testing
@testable import Warp

@Suite("A catalogue brings what a claim needs")
struct CatalogueClaimTests {
    private let entryName: Name = "app.main"

    @Test("closing brings a claim about two shapes the list has")
    func closingBringsAClaimAboutShapesTheListHas() throws {
        // Given. Two libraries that know nothing of each other, a third
        // claiming one's type answers the other's contract, and a program
        // naming neither the claim nor the word that answers it.
        let charting = try Module(
            contracts: ["chart.Plottable": ["height": Signature(returns: .int)]],
            procedures: [
                "chart.draw": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraint: "chart.Plottable"))],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(receiver: .reference([.key("it")]), selector: "chart.Plottable.height"))
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
                    result: .call(Call(receiver: .reference([.key("account")]), selector: "chart.draw"))
                )
            ]
        )

        // When
        let catalogue = try Catalogue([charting, banking, adapting] + Module.standard)
        let closed = catalogue.closing([program])

        // Then. The claim stands in the link, so the pair the program leans on
        // is answered.
        #expect(closed.contains { module in module.claims.isEmpty == false })
        #expect(throws: Never.self) { try Builder().build(closed, entry: entryName) }
    }
}

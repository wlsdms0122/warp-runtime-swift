//
//  FoldedContractTests.swift
//  Warp
//

import Testing
@testable import Warp

@Suite("A folded constant is held to the contract it was handed to")
struct FoldedContractTests {
    private let entryName: Name = "app.main"

    private func documents(returning shape: TypeExpression, giving: Warp.Expression) throws -> [Module] {
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                "app.count": Procedure(
                    signature: Signature(
                        receiver: "it",
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraint: "app.Describable"))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "app.give": Procedure(
                    signature: Signature(returns: shape),
                    body: [],
                    result: giving
                )
            ]
        )
        let program = try Module(
            constants: [
                "app.counted": .call(
                    Call(receiver: .call(Call(selector: "app.give")), selector: "app.count")
                )
            ],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("app.counted")])
                )
            ]
        )
        return [asking, program]
    }

    // Given. A word answering `any` hands a string where a contract is asked,
    // and the reading says nothing about what arrives.
    @Test("a value wearing no name is refused however much of the list is in hand")
    func aNamelessValueIsRefused() throws {
        let modules = try documents(returning: .any, giving: .literal(.string("x"))) + Module.standard

        // When / Then. No claim puts a string under a contract, so a document
        // compiled against part of the list settles this where the whole list
        // would. The refusal stands where the constant is folded, which is the
        // compile itself.
        #expect {
            var compiled: [Compiled] = []

            for origin in try ModuleGraph(modules).standing {
                compiled.append(try Linker().compile(modules[origin], against: compiled))
            }
        } throws: { error in
            "\(error)".contains("string does not answer every word 'app.Describable' asks")
        }

        #expect {
            try Linker().link(modules, entry: entryName)
        } throws: { error in
            "\(error)".contains("string does not answer every word 'app.Describable' asks")
        }
    }
}

//
//  FoldedContractTests.swift
//  WarpTests
//
//  Created by JSilver on 9/10/26.
//

import Testing
@testable import Warp

@Suite("A folded constant is held to the contract it was handed to")
struct FoldedContractTests {
    // MARK: - Property
    private let main: Name = "app.main"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a value wearing no name is refused however much of the list is in hand")
    func aNamelessValueIsRefused() async throws {
        // Given. A procedure answering `any` hands a string where a contract is
        // asked, and the reading says nothing about what arrives.
        let modules = try documents(returning: .any, giving: .literal(.string("x"))) + Module.standard

        // When / Then. No claim puts a string under a contract, so a document
        // compiled against part of the list settles this where the whole list
        // would. The refusal stands where the constant is folded, which is the
        // compile itself.
        await #expect {
            var compiled: [Compiled] = []

            for origin in try ModuleGraph(modules).standing {
                compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
            }
        } throws: { error in
            "\(error)".contains("string does not answer every procedure 'app.Describable' asks")
        }

        await #expect {
            try await Builder().build(modules)
        } throws: { error in
            "\(error)".contains("string does not answer every procedure 'app.Describable' asks")
        }
    }

    @Test("a deferred pair stands where it was folded, not where the walk ended")
    func aDeferredPairStandsWhereItWasFolded() async throws {
        // Given. Two constants leaning on two pairs, settled one after the
        // other. The refusal the list makes stands where the pair was folded,
        // which is the constant that handed it and not whichever was settled
        // last.
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("app.Describable"))], returns: .string)]],
            procedures: [
                "app.count": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T", constraints: ["app.Describable"]))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "app.giveEarly": Procedure(
                    signature: Signature(returns: .any),
                    body: [],
                    result: .cast(.record(["note": .literal(.string("x"))]), as: .named("zed.Plain"), optional: false)
                ),
                "app.giveLate": Procedure(
                    signature: Signature(returns: .any),
                    body: [],
                    result: .cast(.record(["note": .literal(.string("x"))]), as: .named("bank.Plain"), optional: false)
                )
            ]
        )
        let typed = try Module(
            types: ["bank.Plain": .record(["note": .string]), "zed.Plain": .record(["note": .string])],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // `app.aaa` settles first and `app.zzz` last, and the pair the list
        // reports first is `bank.Plain`, which `app.zzz` handed.
        let program = try Module(
            constants: [
                "app.aaa": .call(Call(selector: "app.count", arguments: [.call(Call(selector: "app.giveEarly"))])),
                "app.zzz": .call(Call(selector: "app.count", arguments: [.call(Call(selector: "app.giveLate"))]))
            ],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("app.zzz")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([asking, typed, program] + Module.standard)
        } throws: { error in
            "\(error)".contains("constants.app.zzz:")
                && "\(error)".contains("no document in this link says 'bank.Plain' answers it")
        }
    }

    @Test("a value wearing a name is written down where the table cannot settle")
    func aNamedValueIsWrittenDown() async throws {
        // Given. A procedure answering `any` hands a named record where a
        // contract is asked, and the reading says nothing about what arrives,
        // so nothing is written down where the call is read.
        let typed = try Module(
            types: ["bank.Plain": .record(["note": .string])],
            procedures: ["bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let modules = try documents(
            returning: .any,
            giving: .cast(.record(["note": .literal(.string("x"))]), as: .named("bank.Plain"), optional: false)
        ) + [typed] + Module.standard

        // When. Each document compiled against the ones before it, so the
        // table folding runs against cannot say which types answer.
        var compiled: [Compiled] = []

        for origin in try ModuleGraph(modules).standing {
            compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
        }

        // Then. The pair the fold handed over is answered by the list, which
        // is the same answer the whole graph gives, and both say which
        // declaration was being settled when the fold turned it up.
        for link in [compiled, try await Builder().compile(modules)] {
            #expect {
                try Builder().link(link, supplying: Supplying(Module.standard))
            } throws: { error in
                "\(error)".contains("constants.app.counted:")
                    && "\(error)".contains("no document in this link says 'bank.Plain' answers it")
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func documents(returning type: TypeExpression, giving: Warp.Expression) throws -> [Module] {
        let asking = try Module(
            contracts: ["app.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("app.Describable"))], returns: .string)]],
            procedures: [
                "app.count": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T", constraints: ["app.Describable"]))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "app.give": Procedure(
                    signature: Signature(returns: type),
                    body: [],
                    result: giving
                )
            ]
        )
        let program = try Module(
            constants: [
                "app.counted": .call(
                    Call(selector: "app.count", arguments: [.call(Call(selector: "app.give"))])
                )
            ],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("app.counted")])
                )
            ]
        )
        return [asking, program]
    }
}

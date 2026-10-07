//
//  FoldedContractTests.swift
//  WarpTests
//
//  Created by JSilver on 9/10/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A folded constant is held to the contract it was handed to")
struct FoldedContractTests {
    // MARK: - Property
    private let main: Name = "App.main"

    // MARK: - Initializer
    // MARK: - Test
    @Test("a value that is an instance of no type is refused however much of the list is in hand")
    func aValueOfNoTypeIsRefused() async throws {
        // Given. A procedure answering `Any` hands null where a contract is
        // asked, and the reading says nothing about what arrives.
        let modules = try documents(returning: .any, giving: .literal(.null)) + Module.standard

        // When / Then. Null is an instance of no type a claim names, so no
        // claim anywhere puts it under a contract, and a document compiled
        // against part of the list settles this where the whole list would.
        // The refusal stands where the constant is folded, which is the
        // compile itself.
        await #expect {
            var compiled: [Compiled] = []

            for origin in try ModuleGraph(modules).standing {
                compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
            }
        } throws: { error in
            "\(error)".contains("expected some T: App.Describable, got Null")
        }

        await #expect {
            try await Builder().build(modules)
        } throws: { error in
            "\(error)".contains("expected some T: App.Describable, got Null")
        }
    }

    @Test("a value of a type the language names leans on what the whole list claims")
    func aValueOfALanguageTypeLeansOnTheList() async throws {
        // Given. The same constant handing a string, which is an instance of
        // `String`, and a claim about `String` is one any document may make.
        let modules = try documents(returning: .any, giving: .literal(.string("x"))) + Module.standard

        // When. Compiled against part of the list, the pair is written down
        // rather than judged.
        var compiled: [Compiled] = []

        for origin in try ModuleGraph(modules).standing {
            compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
        }

        // Then. The whole list holds no such claim, and the refusal says so.
        await #expect {
            try await Builder().build(modules)
        } throws: { error in
            "\(error)".contains("hands 'String' where 'App.Describable' is asked, and no document in this link says 'String' answers it")
        }
    }

    @Test("a deferred pair stands where it was folded, not where the walk ended")
    func aDeferredPairStandsWhereItWasFolded() async throws {
        // Given. Two constants leaning on two pairs, settled one after the
        // other. The refusal the list makes stands where the pair was folded,
        // which is the constant that handed it and not whichever was settled
        // last.
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .string)]],
            procedures: [
                "App.count": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T", constraints: ["App.Describable"]))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "App.giveEarly": Procedure(
                    signature: Signature(returns: .any),
                    body: [],
                    result: .cast(.record(["note": .literal(.string("x"))]), as: .named("Zed.Plain"), optional: false)
                ),
                "App.giveLate": Procedure(
                    signature: Signature(returns: .any),
                    body: [],
                    result: .cast(.record(["note": .literal(.string("x"))]), as: .named("Bank.Plain"), optional: false)
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Plain": .record(["note": .string]), "Zed.Plain": .record(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // `App.aaa` settles first and `App.zzz` last, and the pair the list
        // reports first is `Bank.Plain`, which `App.zzz` handed.
        let program = try Module(
            constants: [
                "App.aaa": .call(Call(selector: "App.count", arguments: [.call(Call(selector: "App.giveEarly"))])),
                "App.zzz": .call(Call(selector: "App.count", arguments: [.call(Call(selector: "App.giveLate"))]))
            ],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("App.zzz")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([asking, typed, program] + Module.standard)
        } throws: { error in
            "\(error)".contains("constants.App.zzz:")
                && "\(error)".contains("no document in this link says 'Bank.Plain' answers it")
        }
    }

    @Test("a value wearing a name is written down where the table cannot settle")
    func aNamedValueIsWrittenDown() async throws {
        // Given. A procedure answering `Any` hands a named record where a
        // contract is asked, and the reading says nothing about what arrives,
        // so nothing is written down where the call is read.
        let typed = try Module(
            types: ["Bank.Plain": .record(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let modules = try documents(
            returning: .any,
            giving: .cast(.record(["note": .literal(.string("x"))]), as: .named("Bank.Plain"), optional: false)
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
                "\(error)".contains("constants.App.counted:")
                    && "\(error)".contains("no document in this link says 'Bank.Plain' answers it")
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func documents(returning type: TypeExpression, giving: Warp.Expression) throws -> [Module] {
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .string)]],
            procedures: [
                "App.count": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T", constraints: ["App.Describable"]))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "App.give": Procedure(
                    signature: Signature(returns: type),
                    body: [],
                    result: giving
                )
            ]
        )
        let program = try Module(
            constants: [
                "App.counted": .call(
                    Call(selector: "App.count", arguments: [.call(Call(selector: "App.give"))])
                )
            ],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("App.counted")])
                )
            ]
        )
        return [asking, program]
    }
}

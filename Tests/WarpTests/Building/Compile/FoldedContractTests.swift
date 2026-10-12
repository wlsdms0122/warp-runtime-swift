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
    @Test("a null leans on a claim about Null the way any value leans on its type's")
    func aNullLeansOnAClaimAboutNull() async throws {
        // Given. A procedure answering `Any` hands null, cast to a contract,
        // where the contract is asked, and a document claims it for `Null`.
        let answering = try Module(
            claims: ["Null": ["App.Describable"]],
            procedures: [
                "Null.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .null)], returns: .string),
                    body: [],
                    result: .literal(.string("none"))
                )
            ]
        )
        let asking = try documents(returning: .any, giving: .literal(.null)) + Module.standard

        // When / Then. Null is an instance of `Null`, so the fold writes the
        // pair down and the list answers it, as it does for any other value:
        // with the claim the build stands, and without it the list refuses
        // the pair where it was folded.
        await #expect(throws: Never.self) {
            try await Builder().build(asking + [answering])
        }

        await #expect {
            try await Builder().build(asking)
        } throws: { error in
            "\(error)".contains("constants.counted:")
                && "\(error)".contains("no document in this link says 'Null' answers it")
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
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.count": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T"))],
                        returns: .int,
                        bounds: ["T": ["App.Describable"]]
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                "App.giveEarly": Procedure(
                    signature: Signature(returns: .any),
                    body: [],
                    result: .cast(.struct(["note": .literal(.string("x"))]), as: .named("Zed.Plain"), optional: false)
                ),
                "App.giveLate": Procedure(
                    signature: Signature(returns: .any),
                    body: [],
                    result: .cast(.struct(["note": .literal(.string("x"))]), as: .named("Bank.Plain"), optional: false)
                )
            ]
        )
        let typed = try Module(
            types: ["Bank.Plain": .struct(["note": .string]), "Zed.Plain": .struct(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        // `aaa` settles first and `zzz` last, and the pair the list
        // reports first is `Bank.Plain`, which `zzz` handed.
        let program = try Module(
            constants: [
                "aaa": .call(Call(selector: "App.count", arguments: [.cast(.call(Call(selector: "App.giveEarly")), as: .named("App.Describable"), optional: false)])),
                "zzz": .call(Call(selector: "App.count", arguments: [.cast(.call(Call(selector: "App.giveLate")), as: .named("App.Describable"), optional: false)]))
            ],
            procedures: [
                main: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.name("zzz")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([asking, typed, program] + Module.standard)
        } throws: { error in
            "\(error)".contains("constants.zzz:")
                && "\(error)".contains("no document in this link says 'Bank.Plain' answers it")
        }
    }

    @Test("a value wearing a name is written down where the table cannot decide")
    func aNamedValueIsWrittenDown() async throws {
        // Given. A procedure answering `Any` hands a named struct, cast to a
        // contract, where the contract is asked, and the reading says nothing
        // about what arrives, so nothing is written down where the call is
        // read.
        let typed = try Module(
            types: ["Bank.Plain": .struct(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let modules = try documents(
            returning: .any,
            giving: .cast(.struct(["note": .literal(.string("x"))]), as: .named("Bank.Plain"), optional: false)
        ) + [typed] + Module.standard

        // When. Each document compiled against the ones before it, so the
        // table folding runs against cannot say which types answer.
        var compiled: [Compiled] = []

        for origin in try ModuleGraph(modules).standing {
            compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
        }

        // Then. The pair the fold handed over is answered by the list, which
        // is the same answer the whole graph gives, and both say which
        // declaration was being worked out when the fold turned it up.
        for link in [compiled, try await Builder().compile(modules)] {
            #expect {
                try Builder().link(link, supplying: Supplying(Module.standard))
            } throws: { error in
                "\(error)".contains("constants.counted:")
                    && "\(error)".contains("no document in this link says 'Bank.Plain' answers it")
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func documents(returning type: TypeExpression, giving: Warp.Expression) throws -> [Module] {
        let asking = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.count": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .parameter(name: "T"))],
                        returns: .int,
                        bounds: ["T": ["App.Describable"]]
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
                "counted": .call(
                    Call(
                        selector: "App.count",
                        arguments: [.cast(.call(Call(selector: "App.give")), as: .named("App.Describable"), optional: false)]
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
        return [asking, program]
    }
}

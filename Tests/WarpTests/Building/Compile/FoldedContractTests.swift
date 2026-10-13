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
    @Test("a null answers by a claim about Null the way any value answers by its type's")
    func aNullAnswersByAClaimAboutNull() async throws {
        // Given. A procedure answering `Any` hands null, cast to a contract,
        // where the contract is asked, and a document claims it for `Null`.
        let answering = try Module(
            claims: ["Null": ["App.Describable"]],
            members: ["Null": ["describe"]],
            procedures: [
                "Null.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .null)], returns: .string),
                    body: [],
                    result: .literal(.string("none"))
                )
            ]
        )
        let importing = try documents(
            returning: .any,
            giving: .literal(.null),
            importing: [ClaimPair("Null", "App.Describable")]
        ) + Module.standard
        let asking = try documents(returning: .any, giving: .literal(.null)) + Module.standard

        // When / Then. Null is an instance of `Null`, so the fold asks the
        // claims within the program's reach, as it does for any other value:
        // with the claim imported the build stands, and with the claim
        // beside it and not imported the build refuses where it folded.
        await #expect(throws: Never.self) {
            try await Builder().build(importing + [answering])
        }

        await #expect {
            try await Builder().build(asking + [answering])
        } throws: { error in
            "\(error)".contains("constants.counted:")
                && "\(error)".contains("no claim within reach says 'Null' answers")
        }
    }

    @Test("a value of a type the language names answers by the claims within reach")
    func aValueOfALanguageTypeAnswersByTheClaimsWithinReach() async throws {
        // Given. The same constant handing a string, which is an instance of
        // `String`, and a claim about `String` is one any document may make.
        let modules = try documents(returning: .any, giving: .literal(.string("x"))) + Module.standard

        // When / Then. Compiled one at a time or as a whole, nothing within
        // the program's reach makes such a claim, and the refusal says so.
        var compiled: [Compiled] = []

        await #expect {
            for origin in try ModuleGraph(modules).standing {
                compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
            }
        } throws: { error in
            "\(error)".contains("no claim within reach says 'String' answers")
        }
        await #expect {
            try await Builder().build(modules)
        } throws: { error in
            "\(error)".contains("no claim within reach says 'String' answers")
        }
    }

    @Test("a pair a fold refuses stands at the constant that handed it")
    func aRefusedPairStandsWhereItWasFolded() async throws {
        // Given. Two constants handing two pairs, settled one after the
        // other. The refusal stands where the pair was folded, which is the
        // constant that handed it.
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
        // `aaa` settles first and `zzz` last, so the pair refused is
        // `Zed.Plain`, which `aaa` handed.
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
            "\(error)".contains("constants.aaa:")
                && "\(error)".contains("no claim within reach says 'Zed.Plain' answers")
        }
    }

    @Test("a value wearing a name is judged where it is folded")
    func aNamedValueIsJudgedWhereItIsFolded() async throws {
        // Given. A procedure answering `Any` hands a named struct, cast to a
        // contract, where the contract is asked, and the reading says nothing
        // about what arrives, so only the fold meets the value.
        let typed = try Module(
            types: ["Bank.Plain": .struct(["note": .string])],
            procedures: ["Bank.nothing": Procedure(body: [], result: .literal(.null))]
        )
        let modules = try documents(
            returning: .any,
            giving: .cast(.struct(["note": .literal(.string("x"))]), as: .named("Bank.Plain"), optional: false)
        ) + [typed] + Module.standard

        // When / Then. Each document compiled against the ones before it, or
        // all at once, the fold judges the value by the claims within the
        // program's reach, and says which declaration it was working out.
        var compiled: [Compiled] = []

        await #expect {
            for origin in try ModuleGraph(modules).standing {
                compiled.append(contentsOf: try await Builder().compile([modules[origin]], against: compiled, supplying: Supplying(Module.standard)))
            }
        } throws: { error in
            "\(error)".contains("constants.counted:")
                && "\(error)".contains("no claim within reach says 'Bank.Plain' answers")
        }
        await #expect {
            try await Builder().compile(modules)
        } throws: { error in
            "\(error)".contains("constants.counted:")
                && "\(error)".contains("no claim within reach says 'Bank.Plain' answers")
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func documents(
        returning type: TypeExpression,
        giving: Warp.Expression,
        importing claims: Set<ClaimPair> = []
    ) throws -> [Module] {
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
            importedClaims: claims,
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

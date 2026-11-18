//
//  ObjectSupplyTests.swift
//  WarpTests
//
//  Created by JSilver on 11/2/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// A link reads which document supplies a name off the module where it holds
// the document and off the object where it holds what was compiled, so the
// two have to say the same.
@Suite("An object supplies what its document supplies")
struct ObjectSupplyTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("an object and its module supply the same names, a case's and a type member's spelling among them")
    func anObjectSuppliesWhatItsModuleSupplies() async throws {
        // Given. Every kind of name a document supplies: a public procedure
        // and a private one, a struct, an enum's cases, a contract and its
        // procedure, a claim, a member and a type member
        let module = try Module(
            types: [
                "App.Box": .struct(["item": .int]),
                "App.Light": .enum(["green": [:], "red": [:]])
            ],
            contracts: [
                "App.Describable": [
                    "describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)
                ]
            ],
            claims: ["Int": ["App.Describable"]],
            members: ["Int": ["describe"]],
            typeMembers: ["App.Box": ["Item": .int]],
            procedures: [
                "Int.describe": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .string),
                    body: [returning(.literal(.string("a number")))]
                ),
                "App.hidden": Procedure(signature: Signature(returns: .int), body: [returning(.literal(.int(1)))]),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [returning(.literal(.int(1)))]
                )
            ]
        )
        let sut = try #require(try await Builder().compile(Module.standard + [module]).last)

        // When
        let read = try Compiled(written: try sut.object(), of: sut.identity, fingerprint: sut.fingerprint)

        // Then
        #expect(sut.supplies == module.supplies)
        #expect(read.supplies == module.supplies)
        #expect(module.supplies.contains(.type("App.Light.green")))
        #expect(module.supplies.contains(.type("App.Box.Item")))
    }

    // MARK: - Public
    // MARK: - Private
}

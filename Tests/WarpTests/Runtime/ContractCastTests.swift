//
//  ContractCastTests.swift
//  WarpTests
//
//  Created by JSilver on 10/29/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A cast to a contract as the run reads it")
struct ContractCastTests {
    // MARK: - Property
    private let builder = Builder()

    private static let optional = Head(TypeSpelling.optional, arguments: [.parameter(name: "W")])

    // MARK: - Initializer
    // MARK: - Test
    @Test("a cast of an Optional of a contract holds the type its some holds, and its none as the Optional")
    func castOfAnOptionalOfAContractHoldsWhatItsSomeHolds() async throws {
        // Given. `some` holds 5 read as `Int` at its payload, and `none` holds nothing
        let sut = try Self.describing([
            Statement(
                binding: .constant("some", declared: .optional(.named("App.Described"))),
                expression: .literal(.int(5))
            ),
            Statement(
                binding: .constant("none", declared: .optional(.named("App.Described"))),
                expression: .literal(.null)
            ),
            returning(.array([
                .call(Call(selector: "App.Described.describe", arguments: [.cast(reference("some"), as: .named("App.Described"), optional: false)])),
                .call(Call(selector: "App.Described.describe", arguments: [.cast(reference("none"), as: .named("App.Described"), optional: false)]))
            ]))
        ])

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then. The row of `Int` for the some, and of the Optional for the none
        #expect(try await Executor().run(image) == .array([.string("a number"), .string("an optional")]))
    }

    // MARK: - Public
    // MARK: - Private
    // `Int` and every Optional describing themselves, and an entry running
    // `body`.
    private static func describing(_ body: [Statement]) throws -> Module {
        try Module(
            contracts: [
                "App.Described": [
                    "describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)
                ]
            ],
            claims: ["Int": ["App.Described"], optional: ["App.Described"]],
            members: ["Int": ["describe"], optional: ["describe"]],
            procedures: [
                "Int.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .string),
                    body: [returning(.literal(.string("a number")))]
                ),
                Name("describe").spelled(under: optional.type): Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .optional(.parameter(name: "W")))],
                        returns: .string
                    ),
                    body: [returning(.literal(.string("an optional")))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.string), failing: .these(["cast_refused"])),
                    body: Body(body)
                )
            ]
        )
    }
}

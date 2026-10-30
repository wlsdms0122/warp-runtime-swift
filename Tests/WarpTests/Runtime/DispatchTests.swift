//
//  DispatchTests.swift
//  WarpTests
//
//  Created by JSilver on 10/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A call through a contract as it runs")
struct DispatchTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("reaches the row of the type written at `Self`, whatever value stands there")
    func reachesTheRowOfTheTypeWritten() async throws {
        // Given. `App.Describable.describe` called on 5, whose object writes
        // `String` where the build wrote `Int` at `Self`
        let sut = Builder()
        let modules = Module.standard + [try Self.describingFive()]
        let compiled = try await sut.compile(modules)
        let program = try #require(compiled.last)
        let rewritten = try Self.writingString(atSelfOf: try program.object())
        let read = try Compiled(written: rewritten, of: program.identity, fingerprint: program.fingerprint)

        // When
        let image = try sut.link(compiled.dropLast() + [read], supplying: Supplying(modules))
        let returned = try await Executor().run(image, entry: entryName, arguments: [:])

        // Then. The run read the type and not the value
        #expect(returned == .string("a string"))
    }

    // MARK: - Public
    // MARK: - Private
    // `Int` and `String` conforming to one contract, and an entry calling it
    // on 5.
    private static func describingFive() throws -> Module {
        try Module(
            contracts: [
                "App.Describable": [
                    "describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)
                ]
            ],
            claims: ["Int": ["App.Describable"], "String": ["App.Describable"]],
            members: ["Int": ["describe"], "String": ["describe"]],
            procedures: [
                "Int.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .string),
                    body: [returning(.literal(.string("a number")))]
                ),
                "String.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .string)], returns: .string),
                    body: [returning(.literal(.string("a string")))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        returning(
                            .call(Call(selector: "App.Describable.describe", arguments: [.literal(.int(5))]))
                        )
                    ]
                )
            ]
        )
    }

    // The object with its one lowered type, the `Int` the dispatch writes at
    // `Self`, written as `String`.
    private static func writingString(atSelfOf object: Value) throws -> Value {
        guard
            case let .dictionary(parts) = object,
            parts["loweredTypeTable"] == .array([.array([.int(4)])])
        else {
            throw ExecutionError("the object writes another lowered type table than the one this rewrites")
        }

        return .dictionary(parts.writing("loweredTypeTable", with: .array([.array([.int(6)])])))
    }
}

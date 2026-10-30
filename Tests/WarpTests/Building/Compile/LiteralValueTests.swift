//
//  LiteralValueTests.swift
//  WarpTests
//
//  Created by JSilver on 10/12/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// A host assembling a module in Swift writes a list or a dictionary as a value
// where a document writes it part by part. Either way it is one literal and
// meets the rules a list or dictionary literal meets.
@Suite("A list or dictionary written as a value")
struct LiteralValueTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a dictionary value whose keys read as two types refuses where its place declares no dictionary")
    func aDictionaryValueOfKeysOfTwoTypesRefuses() async throws {
        // Given. `count` takes a value of a contract, which declares no dictionary,
        // so the dictionary is read as keyed by what its keys join to, `Any`
        let sut = try Module(
            imports: ["Standard.Collection.count"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [returning(.call(Call(selector: "Standard.Collection.count", arguments: [.literal(try Self.mixed())])))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("keys a dictionary by Any, which does not conform to `Hashable`")
        }
    }

    @Test("a dictionary value whose keys read as two types stands where a Hashable-keyed dictionary is declared")
    func aDictionaryValueOfKeysOfTwoTypesStandsAtAHashableKeyedDictionary() async throws {
        // Given. The place declares a dictionary, so each key is held to its key
        let sut = try Module(
            imports: ["Standard.Collection.count"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .constant("held", declared: .dictionary(key: .named("Hashable"), value: .int)),
                            expression: .literal(try Self.mixed())
                        ),
                        returning(.call(Call(selector: "Standard.Collection.count", arguments: [reference("held")])))
                    ]
                )
            ]
        )

        // When
        let returned = try await Executor().run(try builder.build([sut] + Module.standard))

        // Then
        #expect(returned == .int(2))
    }

    @Test("a list value holding an Int beside a Double reads the Int as a Double")
    func aListValueReadsAnIntBesideADouble() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.double)),
                    body: [returning(.literal(.array([.int(1), .double(2.5)])))]
                )
            ]
        )

        // When
        let returned = try await Executor().run(try builder.build([sut] + Module.standard))

        // Then
        #expect(returned == .array([.double(1), .double(2.5)]))
    }

    // MARK: - Public
    // MARK: - Private
    private static func mixed() throws -> Value {
        .dictionary(try Value.Dictionary([(key: .int(1), value: .int(1)), (key: .string("a"), value: .int(2))]))
    }
}

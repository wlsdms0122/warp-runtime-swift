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

// A host assembling a module in Swift writes a list or a map as a value
// where a document writes it part by part. Either way it is one literal and
// meets the rules a list or map literal meets.
@Suite("A list or map written as a value")
struct LiteralValueTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a map value whose keys read as two types refuses where its place declares no map")
    func aMapValueOfKeysOfTwoTypesRefuses() async throws {
        // Given. `count` takes a value of a contract, which declares no map,
        // so the map is read as keyed by what its keys join to, `Any`
        let sut = try Module(
            imports: ["Standard.Collection.count"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "Standard.Collection.count", arguments: [.literal(try Self.mixed())]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("keys a map by Any, which does not answer `Hashable`")
        }
    }

    @Test("a map value whose keys read as two types stands where a Hashable-keyed map is declared")
    func aMapValueOfKeysOfTwoTypesStandsAtAHashableKeyedMap() async throws {
        // Given. The place declares a map, so each key is held to its key
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
                        )
                    ],
                    result: .call(Call(selector: "Standard.Collection.count", arguments: [reference("held")]))
                )
            ]
        )

        // When
        let answer = try await Executor().run(try builder.build([sut] + Module.standard))

        // Then
        #expect(answer == .int(2))
    }

    @Test("a list value holding a whole number beside a fraction reads the whole number as the fraction")
    func aListValueReadsAWholeNumberBesideAFraction() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.double)),
                    body: [],
                    result: .literal(.array([.int(1), .double(2.5)]))
                )
            ]
        )

        // When
        let answer = try await Executor().run(try builder.build([sut] + Module.standard))

        // Then
        #expect(answer == .array([.double(1), .double(2.5)]))
    }

    // MARK: - Public
    // MARK: - Private
    private static func mixed() throws -> Value {
        .dictionary(try Value.Dictionary([(key: .int(1), value: .int(1)), (key: .string("a"), value: .int(2))]))
    }
}

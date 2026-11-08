//
//  DictionaryProcedureTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// The procedures a dictionary is read and written by. What a dictionary is belongs
// to the language and is tested there; this is what the standard vocabulary
// returns when one arrives.
@Suite("What the procedures return for a dictionary")
struct DictionaryProcedureTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("setting an entry returns the dictionary with it written")
    func settingReturnsADictionary() async throws {
        // When
        let returned = try await run(
            Self.asking(.call(Call(
                selector: "Standard.Collection.setting",
                arguments: [reference("held"), .literal(.string("b")), .literal(.int(2))]
            ))),
            arguments: ["held": .dictionary(["a": .int(1)]), "key": .string("b")]
        )

        // Then
        #expect(returned == .dictionary(["a": .int(1), "b": .int(2)]))
    }

    @Test("setting under another spelling of a key the dictionary holds writes that entry")
    func settingFindsAKeyBySameness() async throws {
        // When
        let returned = try await run(
            Self.asking(.call(Call(
                selector: "Standard.Collection.setting",
                arguments: [reference("held"), reference("key"), .literal(.int(2))]
            ))),
            arguments: ["held": .dictionary(["caf\u{E9}": .int(1)]), "key": .string("cafe\u{301}")]
        )

        // Then
        #expect(returned == .dictionary(["caf\u{E9}": .int(2)]))
    }

    @Test("a procedure that counts a dictionary counts its entries")
    func countingReadsEitherSpelling() async throws {
        // Given
        let counting = Self.asking(.call(Call(selector: "Standard.Collection.count", arguments: [reference("held")])))

        // When / Then
        #expect(
            try await run(counting, arguments: ["held": .dictionary(["a": .int(1), "b": .int(2)]), "key": .string("")])
                == .int(2)
        )
    }

    // MARK: - Public
    // MARK: - Private
    // An entry handed a dictionary of integers and a key, returning what it
    // asks of them.
    private static func asking(_ returned: Warp.Expression) -> Procedure {
        Procedure(
            signature: Signature(
                parameters: [
                    Parameter(name: "held", type: .dictionary(key: .string, value: .int)),
                    Parameter(name: "key", type: .string)
                ],
                returns: .any,
                failing: .anything
            ),
            body: [returning(returned)]
        )
    }
}

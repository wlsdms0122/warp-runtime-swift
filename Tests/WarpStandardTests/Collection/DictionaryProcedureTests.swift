//
//  DictionaryProcedureTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpStandard

// The procedures a dictionary is read and written by. What a dictionary is belongs
// to the language and is tested there; this is what the standard vocabulary
// answers when one arrives.
@Suite("What the procedures answer for a dictionary")
struct DictionaryProcedureTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("setting a field answers a dictionary, whatever it was sent")
    func settingAnswersADictionary() async throws {
        // Given
        let question = Question<SettingQuery>(
            arguments: ["dictionary": .record(Record(name: "App.Point", ["a": .int(1)])), "key": .string("b"), "value": .int(2)]
        )

        // When
        let answer = try await SettingQuery().evaluate(question)

        // Then
        #expect(answer == .dictionary(["a": .int(1), "b": .int(2)]))
    }

    @Test("setting refuses a key that is not one byte spelling")
    func settingRefusesAKeyOutsideNormalForm() async {
        // Given
        let question = Question<SettingQuery>(
            arguments: ["dictionary": .dictionary(["a": .int(1)]), "key": .string("cafe\u{301}"), "value": .int(2)]
        )

        // When / Then
        await #expect {
            try await SettingQuery().evaluate(question)
        } throws: { error in
            "\(error)".contains("normal form C")
        }
    }

    @Test("a procedure that counts fields counts either spelling")
    func countingReadsEitherSpelling() async throws {
        // Given. The declaration answers `int`, so neither spelling may answer
        // absence
        let held = Question<CountQuery>(arguments: ["collection": .dictionary(["a": .int(1), "b": .int(2)])])
        let laid = Question<CountQuery>(arguments: ["collection": .record(Record(name: "App.Point", ["a": .int(1)]))])

        // When / Then
        #expect(try await CountQuery().evaluate(held) == .int(2))
        #expect(try await CountQuery().evaluate(laid) == .int(1))
    }

    // MARK: - Public
    // MARK: - Private
}

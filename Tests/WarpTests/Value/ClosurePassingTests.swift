//
//  ClosurePassingTests.swift
//  WarpTests
//
//  Created by JSilver on 10/6/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A closure keeps the answers the slots it passed through wrote")
struct ClosurePassingTests {
    // MARK: - Property
    private let types = TypeTable(types: ["bank.A": .record(["k": .string])])

    private var record: LoweredType {
        TypeExpression.named("bank.A").lowered(in: types.loweredTypes)
    }

    private let sut = Closure(
        writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("w")),
        nth: 0,
        linked: nil,
        captured: []
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a closure handed back and forth between a record slot and an any slot keeps two answers")
    func aRoundTripGrowsNoList() {
        // Given
        var closure = sut

        // When
        for _ in 0..<10 {
            closure = closure
                .passing(.any, in: types.loweredTypes)
                .passing(record, in: types.loweredTypes)
        }

        // Then
        #expect(closure.slotAnswers == [.any, record])
    }

    @Test("a slot whose answer settles the last one unchanged adds nothing, and any other is kept")
    func onlyAnAnswerThatChangesNothingIsLeftOut() {
        // Given
        let held = sut.passing(record, in: types.loweredTypes)

        // When
        let again = held.passing(record, in: types.loweredTypes)
        let anything = held.passing(.any, in: types.loweredTypes)
        let orNull = held.passing(.nullable(record), in: types.loweredTypes)
        let text = held.passing(.string, in: types.loweredTypes)

        // Then
        #expect(again.slotAnswers == [record])
        #expect(anything.slotAnswers == [record])
        #expect(orNull.slotAnswers == [record])
        #expect(text.slotAnswers == [record, .string])
    }

    // MARK: - Public
    // MARK: - Private
}

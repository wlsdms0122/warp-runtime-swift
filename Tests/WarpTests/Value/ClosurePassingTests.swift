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

    @Test("a round trip through what holds the answer, a list or a range, grows no list either")
    func aRoundTripInsideGrowsNoList() {
        // Given
        let whole: LoweredType = .int
        let byte: LoweredType = .ranged(.whole(from: 0, to: .through(3)))
        var lists = sut
        var ranges = sut

        // When
        for _ in 0..<10 {
            lists = lists
                .passing(.array(.any), in: types.loweredTypes)
                .passing(.array(record), in: types.loweredTypes)
            ranges = ranges
                .passing(whole, in: types.loweredTypes)
                .passing(byte, in: types.loweredTypes)
        }

        // Then
        #expect(lists.slotAnswers == [.array(.any), .array(record)])
        #expect(ranges.slotAnswers == [whole, byte])
    }

    @Test("a round trip between a declared record and a record of its fields grows no list, at whatever depth it stands", arguments: [
        "itself", "a list", "a nullable", "a field", "a procedure's answer"
    ])
    func aRoundTripThatChangesOnlyANameGrowsNoList(depth: String) {
        // Given
        let fields = TypeExpression.record(["k": .string]).lowered(in: types.loweredTypes)
        let wrapped: (LoweredType) -> LoweredType = { inner in
            switch depth {
            case "a list": .array(inner)
            case "a nullable": .nullable(inner)
            case "a field": .record(LoweredRecord(layout: Layout(name: nil, ordered: ["of"]), fields: [inner]))
            case "a procedure's answer": .procedure(parameters: [], returns: inner, constness: .unstated, isolation: .unstated)
            default: inner
            }
        }
        var closure = sut

        // When
        for _ in 0..<10 {
            closure = closure
                .passing(wrapped(record), in: types.loweredTypes)
                .passing(wrapped(fields), in: types.loweredTypes)
        }

        // Then
        #expect(closure.slotAnswers == [wrapped(record), wrapped(fields)])
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

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
    private let types = TypeTable(
        types: ["bank.A": .record(["k": .string])],
        constraints: ["app.M": [.named("bank.A"), .int]]
    )

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

    @Test("a round trip between a declared record and a record of its fields grows no list, either way round and at whatever depth it stands")
    func aRoundTripThatChangesOnlyANameGrowsNoList() {
        // Given
        let fields = TypeExpression.record(["k": .string]).lowered(in: types.loweredTypes)
        let depths: [(name: String, wrap: (LoweredType) -> LoweredType)] = [
            ("itself", { inner in inner }),
            ("a list", { inner in .array(inner) }),
            ("a nullable", { inner in .nullable(inner) }),
            ("a field", { inner in .record(LoweredRecord(layout: Layout(name: nil, ordered: ["of"]), fields: [inner])) }),
            ("a procedure's answer", { inner in .procedure(parameters: [], returns: inner, constness: .unstated, isolation: .unstated) })
        ]

        for (name, wrap) in depths {
            for (first, second) in [(record, fields), (fields, record)] {
                var closure = sut

                // When
                for _ in 0..<10 {
                    closure = closure
                        .passing(wrap(first), in: types.loweredTypes)
                        .passing(wrap(second), in: types.loweredTypes)
                }

                // Then
                #expect(closure.slotAnswers == [wrap(first), wrap(second)], "\(name), \(first) first")
            }
        }
    }

    @Test("a round trip through a record of the same fields under another name is no round trip")
    func aRoundTripThroughAnotherNameKeepsEveryAnswer() {
        // Given
        let renamed: LoweredType = .record(LoweredRecord(layout: Layout(name: "bank.B", ordered: ["k"]), fields: [.string]))

        // When
        let closure = sut
            .passing(record, in: types.loweredTypes)
            .passing(renamed, in: types.loweredTypes)
            .passing(record, in: types.loweredTypes)

        // Then
        #expect(closure.slotAnswers == [record, renamed, record])
    }

    @Test("a round trip that starts from the closure's own answer takes the list back to nothing")
    func aRoundTripFromItsOwnAnswerKeepsNone() {
        // Given
        let fields = TypeExpression.record(["k": .string])
        let closure = Closure(
            writer: Closure.Writer(document: .compiled(Compiled.Token()), declaration: .procedure("w")),
            nth: 0,
            linked: Linked(
                label: "w",
                origin: 0,
                signature: Signature(returns: fields),
                access: .internal,
                constness: .unstated,
                isolation: .unstated,
                failing: .unstated,
                handsBackAsDeclared: false,
                implementation: .body(
                    LoweredBody(instructions: [], result: nil),
                    Frame(size: 0, parameters: [], variables: [], captures: [], names: [])
                ),
                foldable: true,
                in: types.loweredTypes
            ),
            captured: []
        )

        // When
        let back = closure
            .passing(record, in: types.loweredTypes)
            .passing(fields.lowered(in: types.loweredTypes), in: types.loweredTypes)

        // Then
        #expect(back.slotAnswers.isEmpty)
    }

    @Test("a procedure answering anything and one answering a record keep two answers")
    func aRoundTripBetweenProceduresGrowsNoList() {
        // Given
        let answeringAnything: LoweredType = .procedure(parameters: [], returns: .any, constness: .unstated, isolation: .unstated)
        let answeringRecord: LoweredType = .procedure(parameters: [], returns: record, constness: .unstated, isolation: .unstated)
        var closure = sut

        // When
        for _ in 0..<10 {
            closure = closure
                .passing(answeringAnything, in: types.loweredTypes)
                .passing(answeringRecord, in: types.loweredTypes)
        }

        // Then
        #expect(closure.slotAnswers == [answeringAnything, answeringRecord])
    }

    @Test("a membership slot taking the answer adds nothing, so a round trip through one keeps one answer")
    func aMembershipSlotAddsNothing() {
        // Given
        let membership = TypeExpression.composition(["app.M"]).lowered(in: types.loweredTypes)
        var closure = sut

        // When
        for _ in 0..<10 {
            closure = closure
                .passing(record, in: types.loweredTypes)
                .passing(membership, in: types.loweredTypes)
        }

        // Then
        #expect(closure.slotAnswers == [record])
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

    @Test("an answer before one the walk cannot tell leaves as it was is still borne, and a slot judges it")
    func anAnswerALaterOneCannotBeToldToChangeStaysBorne() {
        // Given
        let byte: LoweredType = .ranged(.whole(from: 0, to: .through(3)))
        let wider: LoweredType = .ranged(.whole(from: 0, to: .through(7)))

        // When
        let closure = sut
            .passing(byte, in: types.loweredTypes)
            .passing(wider, in: types.loweredTypes)

        // Then
        #expect(wider.settlesUnchanged(byte, in: types.loweredTypes) == nil)
        #expect(closure.slotAnswers == [byte, wider])
        #expect(closure.answersBorne(in: types.loweredTypes) == [byte, wider])
    }

    // MARK: - Public
    // MARK: - Private
}

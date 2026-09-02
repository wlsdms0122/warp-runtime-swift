//
//  CastAgreementTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// A cast is judged twice — once by the link, which sees two shapes and asks
// whether any value is both, and once by the run, which sees the value that
// actually arrived and asks whether it is the named shape. The two have to
// agree, and only one of them can be wrong in a way nobody finds out about:
// the link refusing a cast the run would have taken closes a door with no
// value on either side of it to show for it.
//
// So the contract is one-directional. Wherever a value settles into both
// shapes, the link must not call the pair impossible. The other way round is
// deliberately free — `couldBothHold` refuses only what it can prove, and
// everything it cannot read into is left to the run.
//
// This is the same shape of guard `holdsEveryByte` earned: two hand-written
// answers to one question, held together by asking the judge. Every pair the
// restatement got wrong — `object` beside `record`, `int?` beside `string?`,
// `bytes` beside `array<int>`, an int where a double is named, `int?` beside
// `null` — is a witness this walk would have produced on its own.
@Suite("The link calls impossible only what no value satisfies")
struct CastAgreementTests {
    // MARK: - Property
    private let types = TypeTable(
        types: [
            "Person": .record(["name": .string]),
            "Byte": .ranged(.whole(from: 0, to: .through(255))),
            "Ratio": .ranged(.fraction(from: 0, to: .upTo(1))),
            "Maybe": .nullable(.int),
            "Whole": .int,
            // A shape that names itself, so the walk's own guard is exercised
            // by every pair it takes part in.
            "Tree": .record(["children": .array(.named("Tree"))])
        ],
        constraints: [
            "Comparable": [.int, .double, .string],
            "Listed": [.array(.any), .bytes]
        ]
    )

    private let shapes: [TypeExpression] = [
        .any, .never, .null, .bool, .int, .double, .string, .number, .bytes,
        .ranged(.whole(from: 0, to: .through(255))),
        .ranged(.whole(from: 300)),
        .ranged(.whole(to: .through(-1))),
        .ranged(.whole(from: 0, to: .upTo(256))),
        .ranged(.fraction(from: 0, to: .through(1))),
        .ranged(.fraction(from: 0, to: .upTo(1))),
        .ranged(.fraction(from: 300)),
        .array(.int), .array(.any), .array(.byteElement), .array(.double),
        // Elements with nothing in common, because an empty list is of every
        // element type there is and the pair is not impossible for it.
        .array(.string),
        .object(.string), .object(.any), .object(.int),
        .record(["name": .string]),
        .record(["age": .int]),
        .record([:]),
        .nullable(.int), .nullable(.string), .nullable(.array(.int)),
        .named("Person"), .named("Byte"), .named("Ratio"), .named("Maybe"), .named("Whole"),
        .named("Tree"),
        .named("Nothing declares this"),
        .parameter(name: "T"),
        .parameter(name: "N", constraint: "Comparable"),
        .reading(of: "T", path: [.key("inner")]),
        .procedure(nil)
    ]

    private let values: [Value] = [
        .null, .bool(true), .bool(false),
        .int(0), .int(1), .int(255), .int(300), .int(-1),
        .double(0), .double(0.5), .double(1), .double(-2.5), .double(300),
        .string(""), .string("text"),
        .array([]), .array([.int(1), .int(2)]), .array([.int(300)]),
        .array([.string("a")]), .array([.double(0.5)]),
        .bytes([]), .bytes([1, 2]),
        .object([:]), .object(["name": .string("n")]),
        .object(["age": .int(1)]),
        .object(["children": .array([])])
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("no pair some value satisfies is called impossible")
    func theLinkNeverRefusesWhatARunWouldTake() {
        for mine in shapes {
            for theirs in shapes {
                // The witness: one value both judges take. Where there is
                // none, the link is free — it may still allow the pair, and
                // leaving what it cannot prove to the run is the whole bias.
                guard let witness = values.first(where: { value in
                    settles(mine, value) && settles(theirs, value)
                }) else { continue }

                #expect(
                    mine.couldBothHold(theirs, in: types),
                    "\(mine.rendered) and \(theirs.rendered) both settle \(witness)"
                )
            }
        }
    }

    @Test("the question reads the same from either side")
    func theQuestionIsSymmetric() {
        // Given — "could some value be both" names no side, so an answer that
        // depended on which shape was written first would be an answer to a
        // different question. The walk peels one name at a time from whichever
        // side has one, which is exactly where an asymmetry would hide.
        for mine in shapes {
            for theirs in shapes {
                #expect(
                    mine.couldBothHold(theirs, in: types)
                        == theirs.couldBothHold(mine, in: types),
                    "\(mine.rendered) beside \(theirs.rendered)"
                )
            }
        }
    }

    @Test("two ranges with nothing between them are called impossible")
    func rangesThatCannotMeetAreRefused() {
        // Given — the other direction of the contract, which the sweep above
        // cannot reach: it only checks pairs some value satisfies, and a pair
        // no value satisfies is exactly what this walk is for. The bounds are
        // the whole of what tells these apart, so a walk that drops them
        // answers about `int` beside `int` and lets the cast through.
        let pairs: [(TypeExpression, TypeExpression)] = [
            (.ranged(.whole(from: 0, to: .through(5))), .ranged(.whole(from: 10, to: .through(15)))),
            (.ranged(.whole(from: 0, to: .upTo(10))), .ranged(.whole(from: 10))),
            (.ranged(.fraction(from: 0, to: .upTo(1))), .ranged(.fraction(from: 2))),
            // Through the names, because a declared range is the same range.
            (.named("Byte"), .ranged(.whole(from: 300)))
        ]

        // When / Then
        for (mine, theirs) in pairs {
            #expect(
                !mine.couldBothHold(theirs, in: types),
                "\(mine.rendered) and \(theirs.rendered) share no value"
            )
            #expect(
                !theirs.couldBothHold(mine, in: types),
                "\(theirs.rendered) and \(mine.rendered) share no value"
            )
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func settles(_ shape: TypeExpression, _ value: Value) -> Bool {
        (try? shape.settling(value, at: "witness", in: types)) != nil
    }
}

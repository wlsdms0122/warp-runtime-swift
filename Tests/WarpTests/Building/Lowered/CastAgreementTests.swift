//
//  CastAgreementTests.swift
//  WarpTests
//
//  Created by JSilver on 8/30/26.
//

import Foundation
import Testing
@testable import Warp

// A cast is judged twice. Once by the build, which sees two types and asks
// whether any value is both, and once by the run, which sees the value that
// actually arrived and asks whether it is the named type. The two have to
// agree, and only one of them can be wrong in a way nobody finds out about: the
// build refusing a cast the run would have taken closes a door with no value on
// either side of it to show for it.
//
// So the contract is one-directional. Wherever a value settles into both
// types, the build does not call the pair impossible. `couldBothHold` refuses
// only what it can prove, and everything it cannot read into is left to the
// run.
@Suite("The build calls impossible only what no value satisfies")
struct CastAgreementTests {
    // MARK: - Property
    private let types = TypeTable(
        types: [
            "Person": .record(["name": .string]),
            // A name standing for another declared record, so an alias meets
            // the record it names in every pair.
            "Someone": .named("Person"),
            "Byte": .ranged(.whole(from: 0, to: .through(255))),
            "Ratio": .ranged(.fraction(from: 0, to: .upTo(1))),
            "Maybe": .nullable(.int),
            "Whole": .int,
            // A type that names itself, so the walk's own guard is exercised
            // by every pair it takes part in.
            "Tree": .record(["children": .array(.named("Tree"))])
        ],
        constraints: [
            "Comparable": [.int, .double, .string],
            "Listed": [.array(.any), .array(.byteElement)]
        ]
    )

    private let typeExpressions: [TypeExpression] = [
        .any, .never, .null, .bool, .int, .double, .string,
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
        .dictionary(.string), .dictionary(.any), .dictionary(.int),
        .record(["name": .string]),
        .record(["age": .int]),
        .record([:]),
        .nullable(.int), .nullable(.string), .nullable(.array(.int)),
        .named("Person"), .named("Byte"), .named("Ratio"), .named("Maybe"), .named("Whole"),
        .named("Tree"),
        .named("Nothing declares this"),
        .parameter(name: "T"),
        .parameter(name: "N", constraints: ["Comparable"]),
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
        .dictionary([:]), .dictionary(["name": .string("n")]),
        .dictionary(["age": .int(1)]),
        .dictionary(["children": .array([])])
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("no pair some value satisfies is called impossible")
    func theBuildNeverRefusesWhatARunWouldTake() {
        // When / Then
        for mine in typeExpressions {
            for theirs in typeExpressions {
                // The witness: one value both judges take. Where there is none,
                // the build is free. It may still allow the pair, and leaving
                // what it cannot prove to the run is the whole bias.
                guard let witness = values.first(where: { value in
                    settles(mine, value) && settles(theirs, value)
                }) else { continue }

                #expect(
                    couldBothHold(mine, theirs),
                    "\(mine.rendered) and \(theirs.rendered) both settle \(witness)"
                )
            }
        }
    }

    @Test("the question reads the same from either side")
    func theQuestionIsSymmetric() {
        // Given. "could some value be both" names no side, so an answer that
        // depended on which type was written first would be an answer to a
        // different question. The walk peels one name at a time from whichever
        // side has one, which is exactly where an asymmetry would hide.

        // When / Then
        for mine in typeExpressions {
            for theirs in typeExpressions {
                #expect(
                    couldBothHold(mine, theirs)
                        == couldBothHold(theirs, mine),
                    "\(mine.rendered) beside \(theirs.rendered)"
                )
            }
        }
    }

    @Test("two ranges with nothing between them are called impossible")
    func rangesThatCannotMeetAreRefused() {
        // Given. The other direction of the contract, which the sweep above
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
                !couldBothHold(mine, theirs),
                "\(mine.rendered) and \(theirs.rendered) share no value"
            )
            #expect(
                !couldBothHold(theirs, mine),
                "\(theirs.rendered) and \(mine.rendered) share no value"
            )
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Asked of the lowered types, which is where the judgment lives. What a
    // document writes reaches it by lowering.
    private func couldBothHold(_ mine: TypeExpression, _ theirs: TypeExpression) -> Bool {
        mine.lowered(in: types.loweredTypes)
            .couldBothHold(theirs.lowered(in: types.loweredTypes), in: types.loweredTypes)
    }

    private func settles(_ type: TypeExpression, _ value: Value) -> Bool {
        (try? type.settling(value, at: "witness", in: types)) != nil
    }
}

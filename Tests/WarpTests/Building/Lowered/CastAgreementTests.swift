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
            "Person": .struct(["name": .string]),
            // A name standing for another declared struct, so an alias meets
            // the struct it names in every pair.
            "Someone": .alias(.named("Person")),
            "Maybe": .alias(.nullable(.int)),
            "Whole": .alias(.int),
            // A struct that names itself in a field.
            "Tree": .struct(["children": .array(.named("Tree"))]),
            // The layout of `Person` under another name, and two chains of
            // one layout under two names, so a name is all that tells them
            // apart.
            "Human": .struct(["name": .string]),
            "Chain": .struct(["next": .nullable(.named("Chain"))]),
            "Link": .struct(["next": .nullable(.named("Link"))]),
            // Structs holding a declared struct, so a name decides the answer
            // a field deep.
            "Of": .struct(["of": .named("Human")]),
            "Next": .struct(["next": .named("Link")])
        ],
        contracts: ["Comparable": [:]],
        satisfying: ["Comparable": ["Int", "Double", "String"]],
        holdsEveryClaim: true,
        of: Linkage()
    )

    // What the signature these types stand in holds its type parameters to.
    private let bounds: [Name: Set<Name>] = ["N": ["Comparable"]]

    private let typeExpressions: [TypeExpression] = [
        .any, .never, .null, .bool, .int, .double, .string,
        .array(.int), .array(.any), .array(.double),
        // Elements with nothing in common, because an empty list is of every
        // element type there is and the pair is not impossible for it.
        .array(.string),
        .dictionary(key: .string, value: .string), .dictionary(key: .string, value: .any), .dictionary(key: .string, value: .int),
        .nullable(.int), .nullable(.string), .nullable(.array(.int)),
        .named("Person"), .named("Maybe"), .named("Whole"),
        .named("Tree"),
        .named("Nothing declares this"),
        .parameter(name: "T"),
        .parameter(name: "N"),
        .composition(["Comparable"]),
        .projection(of: "T", path: [.name("inner")]),
        .procedure(nil)
    ]

    // Where a name decides the answer: a value read under a declared struct
    // wears its name, at any depth.
    private let namedTypeExpressions: [TypeExpression] = [
        .named("Human"), .named("Chain"), .named("Link"),
        .nullable(.named("Human")),
        .named("Of"),
        .named("Next")
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
        .dictionary(["children": .array([])]),
        .dictionary(["of": .dictionary(["name": .string("n")])]),
        .dictionary(["next": .null]),
        .dictionary(["next": .dictionary(["next": .null])]),
        .dictionary(["next": .dictionary(["next": .dictionary(["next": .null])])])
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("no cast some run takes is called impossible")
    func theBuildNeverRefusesWhatARunWouldTake() {
        // Given
        let all = typeExpressions + namedTypeExpressions

        // When / Then
        for mine in all {
            for theirs in all {
                // The witness: one value that settles where it is read and is
                // then taken by the cast, the way a run meets it. Where there
                // is none, the build is free. It may still allow the pair,
                // and leaving what it cannot prove to the run is the whole
                // bias.
                guard let witness = values.first(where: { value in
                    settled(value, as: theirs).map { read in settled(read, as: mine) != nil } ?? false
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
        // different question
        // When / Then
        for mine in typeExpressions + namedTypeExpressions {
            for theirs in typeExpressions + namedTypeExpressions {
                #expect(
                    couldBothHold(mine, theirs)
                        == couldBothHold(theirs, mine),
                    "\(mine.rendered) beside \(theirs.rendered)"
                )
            }
        }
    }

    @Test("a declared struct and a map of its fields share no value")
    func aStructAndAMapShareNoValue() {
        // Given. A declared struct and a map of its fields
        let named = TypeExpression.named("Person")
        let map = TypeExpression.dictionary(key: .string, value: .string)

        // When / Then. A cast neither writes a name nor takes one off
        #expect(!couldBothHold(named, map), "reading \(map.rendered) as Person")
        #expect(!couldBothHold(map, named), "reading Person as \(map.rendered)")
    }

    @Test("a name or a chain that rules every value out is called impossible")
    func structsThatCannotMeetAreRefused() {
        // Given. The other direction again, for names: a cast and the reading
        // it is written on, where every value the reading may be is refused
        // by the cast. Two structs of one layout under two names are two
        // types, a chain of them included.
        let pairs: [(claim: TypeExpression, reading: TypeExpression)] = [
            (.named("Human"), .named("Person")),
            (.named("Link"), .named("Chain")),
            (.named("Next"), .named("Chain"))
        ]

        // When / Then
        for (claim, reading) in pairs {
            #expect(
                !couldBothHold(claim, reading),
                "no value read as \(reading.rendered) is a \(claim.rendered)"
            )
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Asked of the lowered types, which is where the judgement lives. What a
    // document writes reaches it by lowering.
    private func couldBothHold(_ mine: TypeExpression, _ theirs: TypeExpression) -> Bool {
        mine.lowered(in: types.loweredTypes, bounds: bounds)
            .couldBothHold(reading: theirs.lowered(in: types.loweredTypes, bounds: bounds), in: types.loweredTypes)
    }

    // What a cast to the type answers, the judge a run asks of a value it
    // reads as one: named the way the type names it, every field kept.
    private func settled(_ value: Value, as type: TypeExpression) -> Value? {
        try? type.lowered(in: types.loweredTypes, bounds: bounds).reading(value, optional: false, in: types.loweredTypes)
    }
}

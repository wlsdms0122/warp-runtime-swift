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
            "Maybe": .nullable(.int),
            "Whole": .int,
            // A type that names itself, so the walk's own guard is exercised
            // by every pair it takes part in.
            "Tree": .record(["children": .array(.named("Tree"))]),
            // The layout of `Person` under another name, and two chains of
            // one layout under two names, so a name is all that tells them
            // apart.
            "Human": .record(["name": .string]),
            "Chain": .record(["next": .nullable(.named("Chain"))]),
            "Link": .record(["next": .nullable(.named("Link"))])
        ],
        contracts: ["Comparable": [:]],
        satisfying: ["Comparable": ["Int", "Double", "String"]],
        settled: true,
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
        .dictionary(.string), .dictionary(.any), .dictionary(.int),
        .record(["name": .string]),
        .record(["age": .int]),
        .record([:]),
        .nullable(.int), .nullable(.string), .nullable(.array(.int)),
        .named("Person"), .named("Maybe"), .named("Whole"),
        .named("Tree"),
        .named("Nothing declares this"),
        .parameter(name: "T"),
        .parameter(name: "N"),
        .composition(["Comparable"]),
        .projection(of: "T", path: [.key("inner")]),
        .procedure(nil)
    ]

    // Where a name decides the answer: a value read under a declared record
    // wears its name, at any depth.
    private let namedTypeExpressions: [TypeExpression] = [
        .named("Human"), .named("Chain"), .named("Link"),
        .nullable(.named("Human")),
        .record(["of": .named("Human")]),
        .record(["next": .named("Link")]),
        .record(["next": .record(["next": .named("Link")])])
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

    @Test("the question reads the same from either side, but for a declared record beside a nameless one")
    func theQuestionIsSymmetric() {
        // Given. "could some value be both" names no side, so an answer that
        // depended on which type was written first would be an answer to a
        // different question. The walk peels one name at a time from whichever
        // side has one, which is exactly where an asymmetry would hide. A
        // declared record beside a nameless record or a map is the one pair
        // it tells apart, pinned below.
        let table = types.loweredTypes

        func nominalBesideNameless(_ one: TypeExpression, _ other: TypeExpression) -> Bool {
            let one = one.lowered(in: table, bounds: bounds)
            let other = other.lowered(in: table, bounds: bounds)

            return (table.record(of: one) != nil && other.isNamelessStructure(in: table))
                || (table.record(of: other) != nil && one.isNamelessStructure(in: table))
        }

        // When / Then
        for mine in typeExpressions {
            for theirs in typeExpressions where !nominalBesideNameless(mine, theirs) {
                #expect(
                    couldBothHold(mine, theirs)
                        == couldBothHold(theirs, mine),
                    "\(mine.rendered) beside \(theirs.rendered)"
                )
            }
        }
    }

    @Test("a cast writes a declared record's name onto a nameless value and takes none off")
    func aCastNamesAndNeverUnnames() {
        // Given. A declared record, a nameless record of its fields and a map
        let named = TypeExpression.named("Person")
        let structures: [TypeExpression] = [.record(["name": .string]), .dictionary(.string)]

        // When / Then
        for structure in structures {
            #expect(couldBothHold(named, structure), "reading \(structure.rendered) as Person")
            #expect(!couldBothHold(structure, named), "reading Person as \(structure.rendered)")
        }
    }

    @Test("a name or a chain that rules every value out is called impossible")
    func recordsThatCannotMeetAreRefused() {
        // Given. The other direction again, for names: a cast and the reading
        // it is written on, where every value the reading may be is refused
        // by the cast. A chain is read through its own name as far as the
        // cast goes, so the walk's guard has to tell a question come back
        // from a new one deeper down.
        let fourDeep: TypeExpression = .record(["next": .record(["next": .record(["next": .record(["next": .int])])])])
        let pairs: [(claim: TypeExpression, reading: TypeExpression)] = [
            (.named("Human"), .named("Person")),
            (.named("Link"), .named("Chain")),
            (fourDeep, .named("Chain"))
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

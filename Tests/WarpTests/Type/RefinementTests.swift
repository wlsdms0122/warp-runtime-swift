//
//  RefinementTests.swift
//  WarpTests
//
//  Created by JSilver on 8/30/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// What a range may say. The condition names the kind it refines and the far
// bound says whether it is inside. The near bound always is, which keeps one
// spelling per range.
@Suite("A range is a condition on a number, and it says which number")
struct RefinementTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a fraction range judges fractions, and takes no whole number")
    func aFractionRangeSettles() throws {
        // Given
        let ratio = TypeExpression.ranged(.fraction(from: 0, to: .through(1)))

        // When / Then
        #expect(try ratio.settling(.double(0.5), at: "value") == .double(0.5))
        #expect(try ratio.settling(.double(0), at: "value") == .double(0))
        #expect(try ratio.settling(.double(1), at: "value") == .double(1))

        // A whole number is no fraction, whatever it is worth.
        #expect(throws: (any Error).self) { try ratio.settling(.int(1), at: "value") }
        #expect(throws: (any Error).self) { try ratio.settling(.int(0), at: "value") }

        #expect(throws: (any Error).self) { try ratio.settling(.double(1.5), at: "value") }
        #expect(throws: (any Error).self) { try ratio.settling(.int(2), at: "value") }
        #expect(throws: (any Error).self) { try ratio.settling(.string("0.5"), at: "value") }
    }

    @Test("the far bound is outside where the text says it is")
    func anOpenEdgeExcludesItsBound() throws {
        // Given
        let whole = TypeExpression.ranged(.whole(from: 0, to: .upTo(256)))
        let fraction = TypeExpression.ranged(.fraction(from: 0, to: .upTo(1)))

        // When / Then
        #expect(try whole.settling(.int(255), at: "value") == .int(255))
        #expect(throws: (any Error).self) { try whole.settling(.int(256), at: "value") }

        #expect(try fraction.settling(.double(0.999), at: "value") == .double(0.999))
        #expect(throws: (any Error).self) { try fraction.settling(.double(1), at: "value") }

        // And what it says, it says in its own spelling. The identity a
        // document is written with.
        #expect(whole.rendered == "Int(0..<256)")
        #expect(fraction.rendered == "Double(0.0..<1.0)")
    }

    @Test("the kind under a range decides what it takes, and it takes its own kind alone")
    func acceptanceReadsTheKindUnderTheRange() {
        // Given
        let byte = TypeExpression.ranged(.whole(from: 0, to: .through(255)))
        let ratio = TypeExpression.ranged(.fraction(from: 0, to: .through(1)))

        // When / Then. A fraction slot takes fractions.
        #expect(ratio.accepts(.double))
        #expect(ratio.accepts(.ranged(.fraction(from: 0.5))))

        // And no whole number, however it is bounded.
        #expect(!ratio.accepts(.int))
        #expect(!ratio.accepts(.ranged(.whole(from: 0, to: .through(1)))))

        // Nor does a whole slot take a fraction.
        #expect(!byte.accepts(.double))
        #expect(!byte.accepts(ratio))

        // The far bound's own fact: `..<1.0` and `1.0...` share nothing, and
        // `...1.0` and `1.0...` share the one value at the edge.
        #expect(!TypeExpression.ranged(.fraction(to: .upTo(1)))
            .accepts(.ranged(.fraction(from: 1))))
        #expect(TypeExpression.ranged(.fraction(to: .through(1)))
            .accepts(.ranged(.fraction(from: 1))))
    }

    @Test("a range whose bounds meet on an excluded edge admits nothing")
    func anEmptyOpenRangeRefusesAtTheBuild() async throws {
        // Given. The far bound is outside, so a floor standing on it leaves
        // nothing between them. A slot no call could fill is refused where it
        // was written, the way a range below its own floor is.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "level", type: .ranged(.whole(from: 5, to: .upTo(5))))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    @Test("a bound that is not a number admits nothing")
    func aNanBoundAdmitsNothing() async throws {
        // Given. Nothing compares to a nan, so every ordering question about a
        // range bounded by one answers no and the range holds no value at all.
        // A document cannot spell one; a declaration assembled in the host can,
        // and a slot no call could fill is refused where it was written.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ratio", type: .ranged(.fraction(to: .through(.nan))))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    @Test("an infinite bound orders, so the range it bounds holds what is inside it")
    func anInfiniteBoundIsNotEmpty() throws {
        // Given. `Double(0.0...)` written the long way. An infinity compares
        // like any other bound, so the question a range asks (is this number
        // between them) has an answer, and half the fractions answer yes.
        let half = TypeExpression.Refinement.fraction(from: 0, to: .through(.infinity))

        // When / Then
        #expect(!half.admitsNothing)
        #expect(try TypeExpression.ranged(half).settling(.double(5), at: "value") == .double(5))
        #expect {
            try TypeExpression.ranged(half).settling(.double(-1), at: "value")
        } throws: { error in
            error is ArgumentError && "\(error)".contains("-1.0 is outside Double(0.0...<infinity>)")
        }

        // And the one that says nothing still says nothing.
        #expect(TypeExpression.Refinement.fraction(to: .through(.nan)).admitsNothing)
    }

    @Test("a range with no floor stands on the kind's own")
    func aMissingFloorIsTheKindsFloor() throws {
        // Given. A ceiling on the smallest value the kind has, with the bound
        // outside it. No number is below the smallest one, so nothing is
        // inside, and it is a slot no call could ever fill.

        // When / Then
        #expect(TypeExpression.Refinement.whole(to: .upTo(Int.min)).admitsNothing)
        #expect(TypeExpression.Refinement.fraction(to: .upTo(-.infinity)).admitsNothing)

        // The bound inside is the other answer: the smallest value is itself
        // inside, so the range holds one number.
        let smallest = TypeExpression.Refinement.whole(to: .through(Int.min))

        #expect(!smallest.admitsNothing)
        #expect(try TypeExpression.ranged(smallest)
            .settling(.int(Int.min), at: "value") == .int(Int.min))
    }

    @Test("two whole ranges meet as whole numbers, above where fractions can count")
    func wholeRangesMeetWithoutWidening() {
        // Given. Two ranges sharing exactly one number, chosen where a fraction
        // cannot hold it: 9007199254740997 and 9007199254740996 are one
        // fraction, so comparing them as fractions would lose the gap between
        // them.
        let mine = TypeExpression.Refinement.whole(to: .upTo(9007199254740997))
        let theirs = TypeExpression.Refinement.whole(from: 9007199254740996)

        // When / Then
        #expect(mine.overlaps(theirs))
        #expect(theirs.overlaps(mine))

        // The shared value is real: inside both, as the judge that settles it
        // says.
        let shared = Value.int(9007199254740996)

        #expect(mine.settling(shared) == .settled(shared))
        #expect(theirs.settling(shared) == .settled(shared))

        // And ranges that genuinely share nothing still come out apart.
        #expect(!TypeExpression.Refinement.whole(to: .upTo(9007199254740996))
            .overlaps(theirs))
    }

    @Test("a bound with no spelling is still written, so no two ranges read alike")
    func everyBoundIsSpelled() {
        // Given. A range bounded by a nan beside one bounded by nothing. They
        // are refused for different reasons and an author reads the reason
        // beside the range, so the two cannot come back in the same words.
        let unspellable = TypeExpression.ranged(.fraction(to: .through(.nan)))
        let unbounded = TypeExpression.ranged(.fraction())

        // When / Then. A range saying nothing is the kind, and one type reads
        // one way. `Double(...)` would be a second spelling for what `Double`
        // is.
        #expect(unbounded.rendered == "Double")
        #expect(unspellable.rendered != unbounded.rendered)
    }

    @Test("a range a document cannot spell is said rather than written")
    func anUnspellableBoundIsNotWritten() {
        // Given. An infinity is a bound the language admits on purpose: it
        // orders like any other, and `Double(0.0...)` written the long way is a
        // range half the fractions are inside. What no document has is a
        // spelling for it, and the words a message shows it in read back as an
        // error rather than as the range.
        let unbounded = TypeExpression.Refinement.fraction(from: 0)
        let infinite = TypeExpression.Refinement.fraction(from: 0, to: .through(.infinity))

        // When / Then. Both are ranges the build takes, and only one is a
        // document's
        #expect(!unbounded.admitsNothing)
        #expect(!infinite.admitsNothing)
        #expect(unbounded.spellable)
        #expect(!infinite.spellable)
        #expect(!TypeExpression.Refinement.fraction(to: .through(.nan)).spellable)

        // And a whole bound always is. Its spelling is its digits
        #expect(TypeExpression.Refinement.whole(to: .upTo(.min)).spellable)

        // The message still shows it, in this vocabulary's own terms
        #expect(TypeExpression.ranged(infinite).rendered == "Double(0.0...<infinity>)")
    }

    @Test("a fraction range takes no bytes, since it takes no whole number")
    func aFractionRangeTakesNoBytes() async throws {
        // Given. The compact spelling crosses an `Array<…>` slot whole where
        // the element takes every byte as it is. A fraction range takes no
        // whole number, so no byte arrives there.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "blob", type: .array(.ranged(.fraction(from: 0, to: .through(255)))))
                        ],
                        returns: .array(.double)
                    ),
                    body: [],
                    result: reference("blob")
                )
            ]
        )

        // When / Then
        await #expect(throws: (any Error).self) {
            try await run(sut, arguments: ["blob": .bytes([1, 2])])
        }

        // And a whole range that holds every byte leaves the spelling alone.
        let kept = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "blob", type: .array(.ranged(.whole(from: 0, to: .upTo(256)))))
                        ],
                        returns: .any
                    ),
                    body: [],
                    result: reference("blob")
                )
            ]
        )

        #expect(try await run(kept, arguments: ["blob": .bytes([1, 2])]) == .bytes([1, 2]))
    }

    @Test("what only the run sees is judged at the boundary, in the range's words")
    func aFractionOutsideItsRangeRefusesAtTheBoundary() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ratio", type: .ranged(.fraction(from: 0, to: .upTo(1))))
                        ],
                        returns: .double
                    ),
                    body: [],
                    result: reference("ratio")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["ratio": .double(0.5)]) == .double(0.5))

        await #expect {
            try await run(sut, arguments: ["ratio": .double(1)])
        } throws: { error in
            "\(error)".contains("1.0 is outside Double(0.0..<1.0)")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

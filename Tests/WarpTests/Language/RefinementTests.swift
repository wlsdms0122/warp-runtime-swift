//
//  RefinementTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// What a range may say. It began as one kind (whole numbers, both bounds
// inside) and the two things it could not say were both things programs are
// written against: a position below a length, and a ratio.
//
// So the condition names the kind it refines and the far bound says whether it
// is inside. The near bound always is, which is the convention every half-open
// interval is already read by, and it is what keeps one spelling per range.
@Suite("A range is a condition on a number, and it says which number")
struct RefinementTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Test
    @Test("a fraction range judges fractions, and the whole numbers it widens")
    func aFractionRangeSettles() throws {
        let ratio = TypeExpression.ranged(.fraction(from: 0, to: .through(1)))

        #expect(try ratio.settling(.double(0.5), at: "value") == .double(0.5))
        #expect(try ratio.settling(.double(0), at: "value") == .double(0))
        #expect(try ratio.settling(.double(1), at: "value") == .double(1))

        // A whole number arrives as the fraction it widens to (the one
        // conversion the language has) so the bounds judge what the slot would
        // hold, and the slot holds the fraction.
        #expect(try ratio.settling(.int(1), at: "value") == .double(1))
        #expect(try ratio.settling(.int(0), at: "value") == .double(0))

        #expect(throws: (any Error).self) { try ratio.settling(.double(1.5), at: "value") }
        #expect(throws: (any Error).self) { try ratio.settling(.int(2), at: "value") }
        #expect(throws: (any Error).self) { try ratio.settling(.string("0.5"), at: "value") }
    }

    @Test("the far bound is outside where the text says it is")
    func anOpenEdgeExcludesItsBound() throws {
        let whole = TypeExpression.ranged(.whole(from: 0, to: .upTo(256)))
        let fraction = TypeExpression.ranged(.fraction(from: 0, to: .upTo(1)))

        #expect(try whole.settling(.int(255), at: "value") == .int(255))
        #expect(throws: (any Error).self) { try whole.settling(.int(256), at: "value") }

        #expect(try fraction.settling(.double(0.999), at: "value") == .double(0.999))
        #expect(throws: (any Error).self) { try fraction.settling(.double(1), at: "value") }

        // And what it says, it says in its own spelling. The identity a
        // document is written with.
        #expect(whole.rendered == "int(0..<256)")
        #expect(fraction.rendered == "double(0.0..<1.0)")
    }

    @Test("the kind under a range decides which way a value may widen")
    func acceptanceReadsTheKindUnderTheRange() {
        let byte = TypeExpression.ranged(.whole(from: 0, to: .through(255)))
        let ratio = TypeExpression.ranged(.fraction(from: 0, to: .through(1)))

        // A fraction slot takes a whole reading, here as anywhere.
        #expect(ratio.accepts(.int))
        #expect(ratio.accepts(.ranged(.whole(from: 0, to: .through(1)))))
        #expect(ratio.accepts(.double))

        // And nothing narrows: a whole slot takes no fraction, however the
        // fraction is bounded.
        #expect(!byte.accepts(.double))
        #expect(!byte.accepts(ratio))

        // Bounds that cannot overlap are provably apart, across kinds too.
        #expect(!ratio.accepts(.ranged(.whole(from: 2, to: .through(3)))))
        #expect(ratio.accepts(.ranged(.whole(from: 1, to: .through(3)))))

        // The far bound's own fact: `..<1.0` and `1...` share nothing, and
        // `...1.0` and `1...` share the one value at the edge.
        #expect(!TypeExpression.ranged(.fraction(to: .upTo(1)))
            .accepts(.ranged(.whole(from: 1))))
        #expect(TypeExpression.ranged(.fraction(to: .through(1)))
            .accepts(.ranged(.whole(from: 1))))
    }

    @Test("a range whose bounds meet on an excluded edge admits nothing")
    func anEmptyOpenRangeRefusesAtTheLink() async throws {
        // Given. The far bound is outside, so a floor standing on it leaves
        // nothing between them. A slot no call could fill is refused where it
        // was written, the way a range below its own floor is.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "level": Parameter(type: .ranged(.whole(from: 5, to: .upTo(5))))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

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
                            "ratio": Parameter(type: .ranged(.fraction(to: .through(.nan))))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    @Test("an infinite bound orders, so the range it bounds holds what is inside it")
    func anInfiniteBoundIsNotEmpty() throws {
        // Given. `double(0.0...)` written the long way. An infinity compares
        // like any other bound, so the question a range asks (is this number
        // between them) has an answer, and half the fractions answer yes.
        //
        // Asking for *finiteness* here refused it, and refused it at the
        // declaration, where an author has nothing to fix. What the range
        // needs of a bound is that ordering it says something, which is a nan's
        // failing and not an infinity's.
        let half = TypeExpression.Refinement.fraction(from: 0, to: .through(.infinity))

        #expect(!half.admitsNothing)
        #expect(try TypeExpression.ranged(half).settling(.double(5), at: "value") == .double(5))
        #expect(throws: (any Error).self) {
            try TypeExpression.ranged(half).settling(.double(-1), at: "value")
        }

        // And the one that says nothing still says nothing.
        #expect(TypeExpression.Refinement.fraction(to: .through(.nan)).admitsNothing)
    }

    @Test("a range with no floor stands on the kind's own")
    func aMissingFloorIsTheKindsFloor() {
        // Given. A ceiling on the smallest value the kind has, with the bound
        // outside it. No number is below the smallest one, so nothing is
        // inside, and it is a slot no call could ever fill.
        //
        // What a missing floor means is the question: the judgment that admits
        // values reads it as open downward and answers against every value the
        // kind has, and the one that asks whether anything is inside read it as
        // having nothing to say. One range, two answers, and this spelling is
        // one a document can write.
        #expect(TypeExpression.Refinement.whole(to: .upTo(Int.min)).admitsNothing)
        #expect(TypeExpression.Refinement.fraction(to: .upTo(-.infinity)).admitsNothing)

        // The bound inside is the other answer: the smallest value is itself
        // inside, so the range holds one number.
        let smallest = TypeExpression.Refinement.whole(to: .through(Int.min))

        #expect(!smallest.admitsNothing)
        #expect(try! TypeExpression.ranged(smallest)
            .settling(.int(Int.min), at: "value") == .int(Int.min))
    }

    @Test("two whole ranges meet as whole numbers, above where fractions can count")
    func wholeRangesMeetWithoutWidening() {
        // Given. Two ranges sharing exactly one number, chosen where a fraction
        // cannot hold it: 9007199254740997 and 9007199254740996 are one
        // fraction, so widening loses the gap between them.
        //
        // Widening is what the question across kinds needs, and it was being
        // paid for by every pair. Round-to-nearest-even picks the neighbour by
        // the tie, so the edge moved inward here, and a range pair that shares
        // a value came out apart. A slot refused for a reason no author could
        // find. `int` is sixty-four bits and this band is where timestamps sit.
        let mine = TypeExpression.Refinement.whole(to: .upTo(9007199254740997))
        let theirs = TypeExpression.Refinement.whole(from: 9007199254740996)

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
        // beside the range, so the two cannot come back in the same procedures.
        let unspellable = TypeExpression.ranged(.fraction(to: .through(.nan)))
        let unbounded = TypeExpression.ranged(.fraction())

        // A range saying nothing is the kind, and one type reads one way.
        // `double(...)` would be a second spelling for what `double` is.
        #expect(unbounded.rendered == "double")
        #expect(unspellable.rendered != unbounded.rendered)
    }

    @Test("a range a document cannot spell is said rather than written")
    func anUnspellableBoundIsNotWritten() {
        // Given. An infinity is a bound the language admits on purpose: it
        // orders like any other, and `double(0.0...)` written the long way is a
        // range half the fractions are inside. What no document has is a
        // spelling for it, and the procedures a message shows it in read back as an
        // error rather than as the range.
        let unbounded = TypeExpression.Refinement.fraction(from: 0)
        let infinite = TypeExpression.Refinement.fraction(from: 0, to: .through(.infinity))

        // Then. Both are ranges the build takes, and only one is a document's
        #expect(!unbounded.admitsNothing)
        #expect(!infinite.admitsNothing)
        #expect(unbounded.spellable)
        #expect(!infinite.spellable)
        #expect(!TypeExpression.Refinement.fraction(to: .through(.nan)).spellable)

        // And a whole bound always is. Its spelling is its digits
        #expect(TypeExpression.Refinement.whole(to: .upTo(.min)).spellable)

        // The message still shows it, in this vocabulary's own terms
        #expect(TypeExpression.ranged(infinite).rendered == "double(0.0...<infinity>)")
    }

    @Test("a fraction range reads bytes out, because it changes every one")
    func aFractionRangeUnpacksBytes() async throws {
        // Given. The compact spelling crosses an `array<…>` slot whole only
        // where the element leaves every byte as it is. A fraction range takes
        // every byte and hands on a fraction, so the bytes are read out and
        // each arrives as what the declaration says it is.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "blob": Parameter(
                                type: .array(.ranged(.fraction(from: 0, to: .through(255))))
                            )
                        ],
                        returns: .array(.double)
                    ),
                    body: [],
                    result: reference("blob")
                )
            ]
        )

        #expect(
            try await run(sut, arguments: ["blob": .bytes([1, 2])])
                == .array([.double(1), .double(2)])
        )

        // And a whole range that holds every byte leaves the spelling alone.
        let kept = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "blob": Parameter(
                                type: .array(.ranged(.whole(from: 0, to: .upTo(256))))
                            )
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

    @Test("what only the run sees is judged at the boundary, in the range's procedures")
    func aFractionOutsideItsRangeRefusesAtTheBoundary() async throws {
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "ratio": Parameter(type: .ranged(.fraction(from: 0, to: .upTo(1))))
                        ],
                        returns: .double
                    ),
                    body: [],
                    result: reference("ratio")
                )
            ]
        )

        #expect(try await run(sut, arguments: ["ratio": .double(0.5)]) == .double(0.5))

        await #expect {
            try await run(sut, arguments: ["ratio": .double(1)])
        } throws: { error in
            "\(error)".contains("1.0 is outside double(0.0..<1.0)")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

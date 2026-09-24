//
//  BoundaryTests.swift
//  WarpTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What the standard vocabulary does at the edges.
//
// These are the cases that decide whether two implementations are the same
// language. Everyone agrees what one plus one is; the disagreements live in
// overflow, in division, and in what happens where a whole number meets a
// fraction, and an implementation that wraps where this one refuses is running
// programs this one would not.
//
// So they are written down in `spec/vocabulary.md`, and written here because prose
// ages against an implementation that keeps moving. Until the same cases can be
// run by an implementation that is not this one, this is the closest thing to a
// specification that cannot go stale.
@Suite("The standard vocabulary at its edges")
struct BoundaryTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("what arithmetic takes is decided before it runs")
    func arithmeticIsCheckedBeforeRunning() async throws {
        // Given, while arithmetic declared `any`, a sum of a number and a piece
        // of text was found by running it. In a language whose whole claim is
        // that what can be decided before running is, that was the claim not
        // holding in the most ordinary place a program has.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .call(
                        Call(
                            receiver: .literal(.int(1)),
                            selector: "std.math.plus",
                            arguments: ["value": .literal(.string("a"))]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([module] + Module.standard)
        } throws: { error in
            "\(error)".contains("'N' is read as")
        }
    }

    @Test("what a procedure answers is what it was given, not merely a number")
    func arithmeticAnswersTheKindItWasGiven() async throws {
        // Given. A whole number added to a whole number is a whole number, and
        // a declaration that only said "a number" would not fit anywhere asking
        // for one. Both sides and the answer are one reading, which is what a
        // language with overloading would need several declarations to say.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .call(
                        Call(
                            selector: "wants",
                            arguments: [
                                "it": .call(
                                    Call(
                                        receiver: .literal(.int(1)),
                                        selector: "std.math.plus",
                                        arguments: ["value": .literal(.int(2))]
                                    )
                                )
                            ]
                        )
                    )
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("it")])
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("ordering compares two of a kind, and text is a kind")
    func orderingIsNotOnlyForNumbers() async throws {
        // Given. The procedures that order values order text too, so declaring them
        // as taking numbers said something the procedure does not mean
        #expect(try await answering("std.math.lessThan", .string("a"), .string("b")) == .bool(true))
        #expect(try await answering("std.math.lessThan", .int(1), .int(2)) == .bool(true))
    }

    @Test("a type parameter read two ways that do not fit is a refusal, not a shrug")
    func aDisagreeingHoleIsRefused() async throws {
        // Given. Appending a whole number to a list of text. The hole is read
        // as text by the list and as a number by what is being appended, and
        // widening to `any` was the checker announcing it had stopped checking
        // and announcing it silently: the call then went through.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "names", type: .array(.string))]),
                    body: [],
                    result: .call(
                        Call(
                            receiver: .reference([.key("names")]),
                            selector: "std.collection.appending",
                            arguments: ["value": .literal(.int(1))]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([module] + Module.standard)
        } throws: { error in
            "\(error)".contains("'Element' is read as")
                && "\(error)".contains("int")
                && "\(error)".contains("string")
        }
    }

    @Test("a type parameter read as anything is anything")
    func anyIsTheLoosestReading() async throws {
        // Given. A list of anything, added to twice with two kinds of value.
        // `accepts` cannot order `any` against a type, since everything takes
        // `any` and `any` takes everything, so asking which is looser answers
        // yes both ways and whichever was read first would win. Reading it
        // first is what a receiver does, and that made a list of anything into
        // a list of whatever went in first.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "xs", type: .array(.any))]),
                    body: [
                        Statement(binding: .constant("one"), expression: .call(
                                Call(
                                    receiver: .reference([.key("xs")]),
                                    selector: "std.collection.appending",
                                    arguments: ["value": .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: .call(
                        Call(
                            receiver: .reference([.key("one")]),
                            selector: "std.collection.appending",
                            arguments: ["value": .literal(.string("a"))]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("a name a module declared and the type it stands for are one reading")
    func aDeclaredNameIsNotADisagreement() async throws {
        // Given. The parameter is read as `Tree` by the list and as the record
        // the call wrote. They are the same type, and calling them a
        // disagreement was asking the question without the table that answers
        // it. The same table the rest of the link uses.
        let module = try Module(
            types: ["Tree": .record(["a": .int])],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "trees", type: .array(.named("Tree")))]
                    ),
                    body: [],
                    result: .call(
                        Call(
                            receiver: .reference([.key("trees")]),
                            selector: "std.collection.appending",
                            arguments: ["value": .record(["a": .literal(.int(1))])]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("a type parameter read loosely and tightly holds the loose reading")
    func aWiderReadingHolds() async throws {
        // Given. A list of numbers and a whole number are not a disagreement.
        // One reading takes the other, so the one that holds both is the
        // answer, and refusing here would refuse a program with nothing wrong
        // with it.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "counts", type: .array(.named("std.Numeric")))]),
                    body: [],
                    result: .call(
                        Call(
                            receiver: .reference([.key("counts")]),
                            selector: "std.collection.appending",
                            arguments: ["value": .literal(.int(1))]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("whole-number arithmetic faults at the procedure's edge")
    func wholeArithmeticFaultsPastTheInt() async throws {
        // Given. `int` is 64 bits: a sum past its edge has no int to
        // answer, and the language stops rather than wrapping or answering a
        // silent fraction.
        for (procedure, left, right) in [(Name, Int, Int)]([
            ("std.math.plus", Int.max, 1),
            ("std.math.minus", Int.min, 1),
            ("std.math.times", Int.max, 2)
        ]) {
            // When / Then
            await #expect {
                try await answering(procedure, .int(left), .int(right))
            } throws: { error in
                "\(error)".contains("overflows int")
            }
        }
    }

    @Test("fraction arithmetic with no finite answer refuses")
    func fractionArithmeticRefusesRatherThanEscapes() async throws {
        // Given. The whole path already refuses what an int cannot hold, and
        // the fraction path could answer infinity: a value a program can carry
        // to exactly the first place that tries to write it down. Found by
        // running `1e308 plus 1e308` and being answered inf.
        for (procedure, left, right) in [(Name, Double, Double)]([
            ("std.math.plus", 1e308, 1e308),
            ("std.math.minus", -1e308, 1e308),
            ("std.math.times", 1e308, 10.0)
        ]) {
            // When / Then
            await #expect {
                try await answering(procedure, .double(left), .double(right))
            } throws: { error in
                "\(error)".contains("no finite answer")
            }
        }
    }

    @Test("division answers a fraction, whole or not")
    func divisionAnswersAFraction() async throws {
        // Given. The alternative is two procedures, or one procedure whose answer type
        // depends on whether the division came out even. The second is not a
        // type a signature can hold.
        #expect(try await answering("std.math.dividedBy", .int(7), .int(2)) == .double(3.5))
        #expect(try await answering("std.math.dividedBy", .int(4), .int(2)) == .double(2))
    }

    @Test("division by zero refuses")
    func divisionByZeroRefuses() async throws {
        // Given. A fraction has an answer for this and it is not a number, so
        // answering with it would put something in a program that no later
        // check could talk about
        for (left, right) in [(Value.int(1), Value.int(0)), (.double(1), .double(0))] {
            await #expect {
                try await answering("std.math.dividedBy", left, right)
            } throws: { error in
                "\(error)".contains("zero")
            }
        }
    }

    @Test("a whole number widens to a fraction, and not the other way")
    func wholeNumbersWiden() async throws {
        // Given. Every whole number is a fraction and the reverse is false, so
        // the conversion that cannot lose anything is the one that happens
        #expect(try await answering("std.math.plus", .int(1), .double(0.5)) == .double(1.5))
        #expect(try await answering("std.math.plus", .double(0.5), .int(1)) == .double(1.5))
    }

    // MARK: - Public
    // MARK: - Private
    // One procedure, sent to one value with one operand. The type every arithmetic
    // procedure takes, so the cases above say what they are about and nothing else.
    private func answering(
        _ selector: Name,
        _ receiver: Value,
        _ operand: Value
    ) async throws -> Value {
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .call(
                        Call(
                            receiver: .literal(receiver),
                            selector: selector,
                            arguments: ["value": .literal(operand)]
                        )
                    )
                )
            ]
        )

        return try await Executor()
            .run(try builder.build([module] + Module.standard))
    }
}

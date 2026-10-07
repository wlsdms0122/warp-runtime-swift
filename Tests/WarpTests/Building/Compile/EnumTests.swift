//
//  EnumTests.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

@Suite("The values a parameter's enum admits")
struct EnumTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("an enum no candidate of which fits the type is refused at the build")
    func anUnsatisfiableEnumIsRefused() async throws {
        // Given. Admitting nothing is a fact about the type and the set
        // together, not about the set being empty
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "count", type: .int, candidates: ["fast"])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("an enum that admits nothing is refused at the build")
    func anEmptyEnumIsRefused() async throws {
        // Given. No call could ever fit it, so the declaration is the defect
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "mode", type: .string, candidates: [])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a fraction candidate is judged by the fraction's one spelling", arguments: ["1", "1e0", "1.50", "1e-5"])
    func aFractionCandidateIsJudgedByItsSpelling(dead: String) async throws {
        // Given. A fraction spells with its point, so `1` on a double slot is
        // the int's spelling and a member no fraction could ever match, and
        // `1e0`/`1.00` are second spellings of a fraction that has one
        let sut = try doubleSlot(candidates: ["2.0", dead])

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'\(dead)'")
        }
    }

    @Test("a fraction candidate in the spelling a document writes is alive")
    func aFractionCandidateInItsSpellingIsAlive() async throws {
        // Given. The exponent form included, sign and padding and all
        let sut = try doubleSlot(candidates: ["1.0", "1.5", "1e-05"])

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard)
        }
    }

    @Test("an enum candidate meets a number by its worth, not its bit pattern")
    func anEnumMeetsANumberByWorth() async throws {
        // Given. The two zeros are one worth in the language's own order, so a
        // list that writes one admits the other
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "level", type: .double, candidates: ["0.0", "1.5"])
                        ]
                    ),
                    body: [],
                    result: reference("level")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .double(-0.0)]) == .double(-0.0))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["level": .double(2.5)])
        }
    }

    @Test("a slot that names no one kind reads a candidate as either")
    func aBoundedSlotMeetsEitherKindByWorth() async throws {
        // Given. A contract-bounded parameter takes wholes and fractions
        // alike, so `"1"` is a live candidate and worth carries across kinds: the
        // same rule `number` takes, pinned so the build's candidate judge and
        // this boundary cannot drift apart
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "level", type: .parameter(name: "N", bounds: ["Standard.Numeric"]),
                                candidates: ["1", "2.5"]
                            )
                        ]
                    ),
                    body: [],
                    result: reference("level")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .int(1)]) == .int(1))
        #expect(try await run(sut, arguments: ["level": .double(1.0)]) == .double(1.0))
        #expect(try await run(sut, arguments: ["level": .double(2.5)]) == .double(2.5))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["level": .int(3)])
        }
    }

    @Test("an enum entirely past the bounds admits nothing")
    func anEnumOutsideTheRangeRefuses() async throws {
        // Given. No candidate is a value the range could hold, so the parameter
        // fits no call: the same judgment an empty enum gets
        func module(candidates: [String]) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(
                            parameters: [
                                Parameter(name: "level", type: .ranged(.whole(from: 0, to: .through(255))),
                                    candidates: candidates
                                )
                            ]
                        ),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        }

        // When / Then
        await #expect {
            try await builder.build([module(candidates: ["300", "999"])] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }

        // A live candidate does not excuse a dead one: `300` is a member no
        // call could ever match, and the refusal names it.
        await #expect {
            try await builder.build([module(candidates: ["0", "300"])] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'300'")
        }

        // One value, one spelling: `+1` and `007` are second spellings of
        // numbers that already have one, so neither is a candidate an int slot
        // can spell. The enum admits nothing and refuses.
        await #expect {
            try await builder.build([module(candidates: ["+1", "007"])] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func doubleSlot(candidates: [String]) throws -> Module {
        try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "level", type: .double, candidates: candidates)
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )
    }
}

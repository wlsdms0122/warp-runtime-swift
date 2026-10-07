//
//  RangeTests.swift
//  WarpTests
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// `Int(0...255)`. A range is a slot's condition on a number, not a new kind. It
// is judged where `enum` is: at the build for what the text shows, at the
// boundary for what only the run can see. What the condition may say is
// `RefinementTests`'; this suite is where a whole range is judged.
@Suite("A whole range")
struct RangeTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the bounds speak where the value settles")
    func aRangeSettles() throws {
        // Given
        let declared = TypeExpression.ranged(.whole(from: 0, to: .through(255)))

        // When / Then
        #expect(try declared.settling(.int(0), at: "value") == .int(0))
        #expect(try declared.settling(.int(255), at: "value") == .int(255))
        #expect(throws: (any Error).self) { try declared.settling(.int(-1), at: "value") }
        #expect(throws: (any Error).self) { try declared.settling(.int(256), at: "value") }
        // The value is an int. A fraction worth a member is still a fraction.
        #expect(throws: (any Error).self) { try declared.settling(.double(3), at: "value") }
    }

    @Test("an open end is no condition at all on that side")
    func anOpenEndSettles() throws {
        // Given
        let floor = TypeExpression.ranged(.whole(from: 0))
        let ceiling = TypeExpression.ranged(.whole(to: .through(255)))

        // When / Then
        #expect(try floor.settling(.int(Int.max), at: "value") == .int(Int.max))
        #expect(throws: (any Error).self) { try floor.settling(.int(-1), at: "value") }
        #expect(try ceiling.settling(.int(Int.min), at: "value") == .int(Int.min))
        #expect(throws: (any Error).self) { try ceiling.settling(.int(256), at: "value") }
    }

    @Test("acceptance reads a range as Int, and the bounds wait for the value")
    func aRangeAcceptsAsInt() throws {
        // Given
        let byte = TypeExpression.ranged(.whole(from: 0, to: .through(255)))

        // When / Then. A reading declared int may hold a member. Only what is
        // provably outside is refused before the run.
        #expect(byte.accepts(.int))
        #expect(byte.accepts(.ranged(.whole(from: 0, to: .through(1024)))))
        #expect(!byte.accepts(.double))
        #expect(!byte.accepts(.string))

        // Two ranges are both the text's fact, so bounds that cannot overlap
        // are provably outside. The one meeting acceptance refuses early.
        #expect(!byte.accepts(.ranged(.whole(from: 300, to: .through(400)))))
        #expect(!byte.accepts(.ranged(.whole(from: 256))))
        #expect(!TypeExpression.ranged(.whole(from: 300, to: .through(400))).accepts(byte))
        #expect(byte.accepts(.ranged(.whole(from: 200, to: .through(300)))))
        #expect(byte.accepts(.ranged(.whole(to: .through(0)))))

        // The other way a member is an int, and widens the way one does.
        #expect(TypeExpression.int.accepts(byte))
        #expect(TypeExpression.double.accepts(byte))
        #expect(!TypeExpression.string.accepts(byte))
    }

    @Test("an argument only the run sees is judged at the boundary")
    func aRuntimeValueIsJudgedAtTheBoundary() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "level", type: .ranged(.whole(from: 0, to: .through(255))))]
                    ),
                    body: [],
                    result: reference("level")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .int(255)]) == .int(255))

        await #expect {
            try await run(sut, arguments: ["level": .int(256)])
        } throws: { error in
            "\(error)".contains("outside Int(0...255)")
        }
    }

    @Test("a constant argument is judged at the build")
    func aConstantArgumentIsJudgedAtTheBuild() async throws {
        // Given. The argument is text, so the miss is the build's to see
        let sut = try Module(
            procedures: [
                "paint": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "level", type: .ranged(.whole(from: 0, to: .through(255))))]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "paint", arguments: [.literal(.int(256))]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("outside Int(0...255)")
        }
    }

    @Test("a range that admits nothing refuses where it was written")
    func anEmptyRangeRefusesAtTheBuild() async throws {
        // Given. No whole number is at once at least 9 and at most 1
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "level", type: .ranged(.whole(from: 9, to: .through(1))))]
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

    @Test("Standard declares Byte, and a name resolves to its range")
    func byteIsANamedRange() async throws {
        // Given. `byte = int(0...255)`, declared where every bundle can name it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .named("Standard.Byte"))]
                    ),
                    body: [],
                    result: reference("value")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["value": .int(255)]) == .int(255))

        await #expect {
            try await run(sut, arguments: ["value": .int(256)])
        } throws: { error in
            "\(error)".contains("outside Int(0...255)")
        }
    }

    @Test("a range fills a procedure's first parameter, the way an Int does")
    func aRangeFillsAProceduresFirstParameter() async throws {
        // Given. A range's value stands where the int it narrows stands
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "level", type: .ranged(.whole(from: -10, to: .through(10))))]
                    ),
                    body: [],
                    result: .call(Call(selector: "Standard.Math.absolute", arguments: [reference("level")]))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .int(-3)]) == .int(3))
    }

    @Test("what a range answers stays inside the wider slot it fills")
    func aRangeReadingFillsAnIntSlot() async throws {
        // Given. A byte-typed value handed to an int slot: provably inside
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "level", type: .ranged(.whole(from: 0, to: .through(255))))]
                    ),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [reference("level")]))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .int(7)]) == .int(7))
    }

    // MARK: - Public
    // MARK: - Private
}

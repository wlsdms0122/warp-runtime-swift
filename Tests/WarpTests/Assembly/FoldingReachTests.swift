//
//  FoldingReachTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Testing
@testable import Warp
@testable import WarpStandard

@Suite("What a constant is allowed to settle from")
struct FoldingReachTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Test
    @Test("a constant settles from the standard vocabulary")
    func aConstantSettlesFromTheStandardVocabulary() async throws {
        // Given. A constant written from a procedure the specification names.
        let document = try Module(
            imports: ["std.math.plus"],
            constants: [
                "sum": .call(Call(receiver: .literal(.int(2)), selector: "std.math.plus", arguments: ["value": .literal(.int(3))]))
            ],
            procedures: ["app.entry": Procedure(signature: Signature(returns: .int), body: [], result: reference("sum"))]
        )

        // When. It is built with the vocabulary it names.
        let image = try await builder.build(Module.standard + [document], entry: "app.entry")

        // Then. The answer is in the image before anything runs.
        #expect(try await Executor().run(image) == .int(5))
    }

    @Test("a constant refuses to settle from a procedure a caller brought")
    func aConstantRefusesAProcedureACallerBrought() async throws {
        // Given. A procedure whose code the caller supplied, answering without
        // running, and a constant written from it.
        let brought = try Module(
            procedures: [
                "app.seat": Procedure(
                    signature: Signature(of: SeatQuery.self, returns: .int),
                    implementation: .query(SeatQuery())
                )
            ]
        )
        let document = try Module(
            imports: ["app.seat"],
            constants: ["seat": .call(Call(selector: "app.seat"))],
            procedures: ["app.entry": Procedure(signature: Signature(returns: .int), body: [], result: reference("seat"))]
        )

        // When and then. What the procedure answers is its code's, and the
        // compiled document says nothing about which code that was.
        await #expect(throws: BuildError.self) {
            try await builder.build(Module.standard + [brought, document], entry: "app.entry")
        }
    }

    @Test("a constant refuses a body in another document that reaches one")
    func aConstantRefusesABodyThatReachesOne() async throws {
        // Given. A body that answers without running and calls the brought
        // procedure, laid down before the document whose constant calls it, so
        // the body is lowered and a fold could run it.
        let brought = try Module(
            procedures: [
                "app.seat": Procedure(
                    signature: Signature(of: SeatQuery.self, returns: .int),
                    implementation: .query(SeatQuery())
                )
            ]
        )
        let between = try Module(
            imports: ["app.seat"],
            procedures: [
                "app.row": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "app.seat"))
                )
            ]
        )
        let document = try Module(
            imports: ["app.row"],
            constants: ["row": .call(Call(selector: "app.row"))],
            procedures: ["app.entry": Procedure(signature: Signature(returns: .int), body: [], result: reference("row"))]
        )

        // When and then. The refusal is about what the fold reaches, not about
        // what the constant wrote, so one written name away is still refused.
        await #expect(throws: BuildError.self) {
            try await builder.build(Module.standard + [brought, between, document], entry: "app.entry")
        }
    }

    @Test("a constant refuses a body its own document declares")
    func aConstantRefusesABodyBesideIt() async throws {
        // Given. A body declared beside the constant that calls it.
        let document = try Module(
            constants: ["row": .call(Call(selector: "app.row"))],
            procedures: [
                "app.row": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(7))),
                "app.entry": Procedure(signature: Signature(returns: .int), body: [], result: reference("row"))
            ]
        )

        // When and then. That body is being resolved beside the constants it
        // may read, so running it would be a circle with no start.
        await #expect(throws: BuildError.self) {
            try await builder.build(Module.standard + [document], entry: "app.entry")
        }
    }

    @Test("a constant refuses one brought by a module compiled earlier")
    func aConstantRefusesOneBroughtByACompiledModule() async throws {
        // Given. The brought procedure compiled on its own, the way a caller
        // that means to link many documents compiles a vocabulary once.
        let brought = try Module(
            procedures: [
                "app.seat": Procedure(
                    signature: Signature(of: SeatQuery.self, returns: .int),
                    implementation: .query(SeatQuery())
                )
            ]
        )
        let supplying = try Supplying(Module.standard + [brought])
        let baked = try await builder.compile(Module.standard + [brought])
        let document = try Module(
            imports: ["app.seat"],
            constants: ["seat": .call(Call(selector: "app.seat"))],
            procedures: ["app.entry": Procedure(signature: Signature(returns: .int), body: [], result: reference("seat"))]
        )

        // When and then. The row came back from an object rather than from the
        // module, and what it may be folded through came back with it.
        await #expect(throws: BuildError.self) {
            try await builder.compile([document], against: baked, supplying: supplying)
        }
    }

    // MARK: - Private
}

private struct SeatQuery: Query {
    typealias Parameters = NoParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        .int(7)
    }

    // MARK: - Private
}

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
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("sum"))]
        )

        // When. It is built with the vocabulary it names.
        let image = try await builder.build(Module.standard + [document])

        // Then. The answer is in the image before anything runs.
        #expect(try await Executor().run(image, entry: "app.entry") == .int(5))
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
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("seat"))]
        )

        // When and then. What the procedure answers is its code's, and the
        // compiled document says nothing about which code that was.
        await #expect(throws: BuildError.self) {
            try await builder.build(Module.standard + [brought, document])
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
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("row"))]
        )

        // When and then. The refusal is about what the fold reaches, not about
        // what the constant wrote, so one written name away is still refused.
        await #expect(throws: BuildError.self) {
            try await builder.build(Module.standard + [brought, between, document])
        }
    }

    @Test("a constant refuses to settle to a closure holding a variable of the fold's run")
    func aConstantRefusesAClosureHoldingABox() async throws {
        // Given. A procedure in an earlier document declaring a variable and
        // answering a closure that reads it, and a constant settling from it:
        // the fold runs the body, and the closure takes a hold on its box.
        let maker = try Module(
            procedures: [
                "app.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [Statement(binding: .variable("tally"), expression: .literal(.int(0)))],
                    result: .closure(Procedure(body: [], result: reference("tally")))
                )
            ]
        )
        let document = try Module(
            imports: ["app.make"],
            constants: ["held": .call(Call(selector: "app.make"))],
            procedures: [
                "app.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("held"), arguments: [])
                )
            ]
        )

        // When and then. The box is the fold's run's, and a link holds values.
        await #expect {
            try await builder.build(Module.standard + [maker, document])
        } throws: { error in
            "\(error)".contains("run that folded it")
        }
    }

    @Test("a variable's start refuses to settle to a closure holding a variable of the fold's run")
    func aVariableStartRefusesAClosureHoldingABox() async throws {
        // Given. The same procedure, settling a variable's start instead.
        let maker = try Module(
            procedures: [
                "app.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int))),
                    body: [Statement(binding: .variable("tally"), expression: .literal(.int(0)))],
                    result: .closure(Procedure(body: [], result: reference("tally")))
                )
            ]
        )
        let document = try Module(
            imports: ["app.make"],
            variables: ["held": .call(Call(selector: "app.make"))],
            procedures: [
                "app.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .apply(reference("held"), arguments: [])
                )
            ]
        )

        // When and then. A variable's start passes the gate a constant does.
        await #expect {
            try await builder.build(Module.standard + [maker, document])
        } throws: { error in
            "\(error)".contains("run that folded it")
        }
    }

    @Test("a constant refuses a body its own document declares")
    func aConstantRefusesABodyBesideIt() async throws {
        // Given. A body declared beside the constant that calls it.
        let document = try Module(
            constants: ["row": .call(Call(selector: "app.row"))],
            procedures: [
                "app.row": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(7))),
                "app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("row"))
            ]
        )

        // When and then. That body is being resolved beside the constants it
        // may read, so running it would be a circle with no start.
        await #expect(throws: BuildError.self) {
            try await builder.build(Module.standard + [document])
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
            procedures: ["app.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("seat"))]
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

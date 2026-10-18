//
//  FoldingReachTests.swift
//  WarpTests
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpStandard
import WarpTestSupport

@Suite("What a constant is allowed to settle from")
struct FoldingReachTests {
    private struct SeatQuery: Query {
        typealias Parameters = NoParameters

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            .int(7)
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant settles from the standard vocabulary")
    func aConstantSettlesFromTheStandardVocabulary() async throws {
        // Given. A constant written from a procedure the specification names.
        let document = try Module(
            imports: ["Standard.Numeric.plus"],
            constants: [
                "sum": .call(Call(selector: "Standard.Numeric.plus", arguments: [.literal(.int(2)), .literal(.int(3))]))
            ],
            procedures: ["App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("sum"))]
        )

        // When. It is built with the vocabulary it names.
        let image = try await builder.build(Module.standard + [document])

        // Then. The answer is in the image before anything runs.
        #expect(try await Executor().run(image, entry: "App.entry") == .int(5))
    }

    @Test("a constant refuses to settle from a procedure the host brought")
    func aConstantRefusesAProcedureTheHostBrought() async throws {
        // Given. A procedure whose code the host supplied, answering without
        // running, and a constant written from it.
        let brought = try Module(
            procedures: [
                "App.seat": Procedure(
                    signature: Signature(of: SeatQuery.self, returns: .int, constness: .const),
                    implementation: .query(SeatQuery())
                )
            ]
        )
        let document = try Module(
            imports: ["App.seat"],
            constants: ["seat": .call(Call(selector: "App.seat"))],
            procedures: ["App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("seat"))]
        )

        // When / Then. What the procedure answers is its code's, and the
        // compiled document says nothing about which code that was.
        await #expect {
            try await builder.build(Module.standard + [brought, document])
        } throws: { error in
            error is BuildError && "\(error)".contains("'App.seat' is a procedure the host brought")
        }
    }

    @Test("a constant refuses a body in another document that reaches one")
    func aConstantRefusesABodyThatReachesOne() async throws {
        // Given. A body that answers without running and calls the brought
        // procedure, laid down before the document whose constant calls it, so
        // the body is lowered and a fold could run it.
        let brought = try Module(
            procedures: [
                "App.seat": Procedure(
                    signature: Signature(of: SeatQuery.self, returns: .int, constness: .const),
                    implementation: .query(SeatQuery())
                )
            ]
        )
        let between = try Module(
            imports: ["App.seat"],
            procedures: [
                "App.row": Procedure(
                    signature: Signature(returns: .int, constness: .const),
                    body: [],
                    result: .call(Call(selector: "App.seat"))
                )
            ]
        )
        let document = try Module(
            imports: ["App.row"],
            constants: ["row": .call(Call(selector: "App.row"))],
            procedures: ["App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("row"))]
        )

        // When / Then. The refusal is about what the fold reaches, not about
        // what the constant wrote, so one written name away is still refused.
        await #expect {
            try await builder.build(Module.standard + [brought, between, document])
        } throws: { error in
            error is BuildError && "\(error)".contains("'App.seat' is a procedure the host brought")
        }
    }

    @Test("a constant refuses to settle to a closure holding a variable of the fold's run")
    func aConstantRefusesAClosureHoldingABox() async throws {
        // Given. A procedure in an earlier document declaring a variable and
        // answering a closure that reads it, and a constant settling from it:
        // the fold runs the body, and the closure takes a hold on its box.
        let maker = try Module(
            procedures: [
                "App.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int, failing: .anything)), constness: .const),
                    body: [Statement(binding: .variable("tally"), expression: .literal(.int(0)))],
                    result: .closure(Procedure(signature: Signature(returns: .int), body: [], result: reference("tally")))
                )
            ]
        )
        let document = try Module(
            imports: ["App.make"],
            constants: ["held": .call(Call(selector: "App.make"))],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int, failing: .anything),
                    body: [],
                    result: .apply(reference("held"), arguments: [])
                )
            ]
        )

        // When / Then. The box is the fold's run's, and a link holds values.
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
                "App.make": Procedure(
                    signature: Signature(returns: .procedure(ProcedureType(returns: .int, failing: .anything)), constness: .const),
                    body: [Statement(binding: .variable("tally"), expression: .literal(.int(0)))],
                    result: .closure(Procedure(signature: Signature(returns: .int), body: [], result: reference("tally")))
                )
            ]
        )
        let document = try Module(
            imports: ["App.make"],
            variables: ["held": .call(Call(selector: "App.make"))],
            procedures: [
                "App.entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int, failing: .anything),
                    body: [],
                    result: .apply(reference("held"), arguments: [])
                )
            ]
        )

        // When / Then. A variable's start passes the gate a constant does.
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
            constants: ["row": .call(Call(selector: "App.row"))],
            procedures: [
                "App.row": Procedure(signature: Signature(returns: .int, constness: .const), body: [], result: .literal(.int(7))),
                "App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("row"))
            ]
        )

        // When / Then. That body is being resolved beside the constants it
        // may read, so running it would be a cycle with no start.
        await #expect {
            try await builder.build(Module.standard + [document])
        } throws: { error in
            error is BuildError
                && "\(error)".contains("this procedure's body is being resolved beside the constants it may read")
        }
    }

    @Test("a constant refuses one brought by a module compiled earlier")
    func aConstantRefusesOneBroughtByACompiledModule() async throws {
        // Given. The brought procedure compiled on its own, the way a host
        // that means to link many documents compiles a vocabulary once.
        let brought = try Module(
            procedures: [
                "App.seat": Procedure(
                    signature: Signature(of: SeatQuery.self, returns: .int, constness: .const),
                    implementation: .query(SeatQuery())
                )
            ]
        )
        let supplying = try Supplying(Module.standard + [brought])
        let baked = try await builder.compile(Module.standard + [brought])
        let document = try Module(
            imports: ["App.seat"],
            constants: ["seat": .call(Call(selector: "App.seat"))],
            procedures: ["App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("seat"))]
        )

        // When / Then. The row came back from an object rather than from the
        // module, and what it may be folded through came back with it.
        await #expect {
            try await builder.compile([document], against: baked, supplying: supplying)
        } throws: { error in
            error is BuildError && "\(error)".contains("'App.seat' is a procedure the host brought")
        }
    }

    @Test("a body's constant-headed call runs a written procedure, resolved")
    func aBodyFoldsThroughAWrittenProcedure() async throws {
        // Given. The constants are settled and the procedures resolved by the time a
        // body folds, so a constant-headed call may run a written procedure: the
        // cycle the settling refuses is the constants' own
        let sut = try Module(
            constants: ["greeting": .literal(.string("hi"))],
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(selector: "Standard.Collection.count", arguments: [reference("of")]))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "shout", arguments: [reference("greeting")]))
                )
            ]
        )

        // When / Then. Folded at the build to the value the resolved body
        // answers
        #expect(try await run(sut) == .int(2))
    }

    @Test("a constant settles through a contract alike however the host split the documents between compiles")
    func aConstantThroughAContractIgnoresHowTheDocumentsWereSplit() async throws {
        // Given. The contract's document names a type of a third, and the
        // claim and its declaration stand in a document the program never
        // names, so the program stands on the contract and the third alone
        let thing = try Module(types: ["Z.Thing": .alias(.int)])
        let contract = try Module(
            imports: ["Z.Thing"],
            contracts: [
                "App.Joinable": [
                    "join": Signature(
                        parameters: [Parameter(name: "of", type: .selfType), Parameter(name: "other", type: .selfType)],
                        returns: .selfType,
                        constness: .const,
                        isolation: .isolated
                    )
                ]
            ],
            procedures: [
                "App.keep": Procedure(signature: Signature(parameters: [Parameter(name: "it", type: .named("Z.Thing"))]), body: [], result: .literal(.null))
            ]
        )
        let answering = try Module(
            imports: ["App.Joinable"],
            claims: ["Int": ["App.Joinable"]],
            members: ["Int": ["join"]],
            procedures: [
                "Int.join": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .int), Parameter(name: "other", type: .int)],
                        returns: .int,
                        constness: .const,
                        isolation: .isolated
                    ),
                    body: [],
                    result: reference("of")
                )
            ]
        )
        let program = try Module(
            imports: ["App.Joinable.join"],
            constants: ["joined": .call(Call(selector: "App.Joinable.join", arguments: [.literal(.int(1)), .literal(.int(2))]))],
            procedures: ["App.entry": Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("joined"))]
        )

        // When / Then. Handed over at once, and compiled apart first, the
        // constant refuses the same way
        await #expect {
            try await builder.build(Module.standard + [contract, answering, thing, program])
        } throws: { error in
            "\(error)".contains("no claim within reach says 'Int' answers 'App.Joinable'")
        }

        await #expect {
            let laid = try await builder.compile([contract, answering, thing], against: [], supplying: Supplying(Module.standard))

            _ = try await builder.compile([program], against: laid, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("no claim within reach says 'Int' answers 'App.Joinable'")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

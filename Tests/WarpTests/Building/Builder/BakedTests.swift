//
//  BakedTests.swift
//  WarpTests
//
//  Created by JSilver on 9/10/26.
//

import Testing
@testable import Warp
@testable import WarpStandard

@Suite("A caller compiles documents once and links them many times")
struct BakedTests {
    // A procedure answering a number, which says whether it touches anything shared.
    private struct CountingQuery: Query {
        typealias Parameters = NoParameters

        // MARK: - Property
        let isolated: Bool

        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            .int(1)
        }

        // MARK: - Private
    }

    // Two procedures answering the same way, each reading its one argument under its
    // own name.
    private struct OfQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            question[.of]
        }

        // MARK: - Private
    }

    private struct ValueQuery: Query {
        enum Parameters: Int, ParameterSet {
            case value

            // MARK: - Property
            var declared: Parameter { Parameter(name: "value", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            question[.value]
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    private var entry: Name { "app.add1" }

    // MARK: - Initializer
    // MARK: - Test
    @Test("a vocabulary compiled once answers a document that arrives after it")
    func aBakedVocabularyAnswersALaterDocument() async throws {
        // Given. The standard vocabulary compiled on its own, the way a host
        // that means to link many documents against it compiles it once.
        let baked = try await builder.compile(Module.standard)
        let arriving = try adding(1)

        // When. The document that arrives is the only one compiled.
        let image = try await builder.link(
            baked + (try builder.compile([arriving], against: baked, supplying: Supplying(Module.standard))),
            supplying: Supplying(Module.standard)
        )

        // Then. It runs, and answers what the same documents linked whole answer.
        let whole = try await builder.build(Module.standard + [arriving])

        #expect(try await Executor().run(image, entry: entry, arguments: ["value": .int(41)]) == .int(42))
        #expect(try await Executor().run(whole, entry: entry, arguments: ["value": .int(41)]) == .int(42))
    }

    @Test("documents compiled together are ordered by what they reach")
    func documentsAreOrderedByWhatTheyReach() async throws {
        // Given. Two documents handed over with the one that reaches the other
        // first, which is the order a host has no way to sort out.
        let reaching = try Module(
            imports: ["app.add1"],
            procedures: [
                "app.twice": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "value", type: .int)], returns: .int),
                    body: [
                        Statement(
                            binding: .constant("once"),
                            expression: .call(
                                Call(selector: "app.add1", arguments: [.reference([.key("value")])])
                            )
                        )
                    ],
                    result: .call(Call(selector: "app.add1", arguments: [reference("once")]))
                )
            ]
        )

        // When.
        let baked = try await builder.compile(Module.standard)
        let compiled = try await builder.compile(
            [reaching, try adding(1, called: "app.add1")],
            against: baked,
            supplying: Supplying(Module.standard)
        )
        let image = try builder.link(baked + compiled, supplying: Supplying(Module.standard))

        // Then.
        #expect(try await Executor().run(image, entry: "app.twice", arguments: ["value": .int(40)]) == .int(42))
    }

    @Test("a procedure nothing compiled answers is refused where it is sent")
    func aProcedureNothingAnswersIsRefused() async throws {
        // Given. A document sending a procedure neither it nor the vocabulary
        // declares.
        let arriving = try Module(
            imports: ["app.missing"],
            procedures: [
                "app.main": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "app.missing"))
                )
            ]
        )

        // When / Then.
        await #expect {
            try await builder.compile(
                [arriving],
                against: try await builder.compile(Module.standard),
                supplying: Supplying(Module.standard)
            )
        } throws: { error in
            "\(error)".contains("'app.missing', which no module in this link declares")
        }
    }

    @Test("a document laid without what it sends is refused past a call through a contract")
    func aDocumentLaidWithoutWhatItSendsIsRefused() async throws {
        // Given. A document sending a contract's procedure, which no row
        // answers, before a procedure another document declares.
        let bank = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            contracts: [
                "app.Describable": [
                    "describe": Signature(parameters: [Parameter(name: "of", type: .named("app.Describable"))], returns: .string)
                ]
            ],
            claims: ["bank.Account": ["app.Describable"]],
            procedures: [
                "bank.Account.describe": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("bank.Account"))], returns: .string),
                    body: [],
                    result: .literal(.string("a"))
                )
            ]
        )
        let sending = try Module(
            procedures: [
                "app.main": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .constant("account"),
                            expression: .cast(.record(["balance": .literal(.int(7))]), as: .named("bank.Account"), optional: false)
                        ),
                        Statement(
                            binding: .constant("said"),
                            expression: .call(Call(selector: "app.Describable.describe", arguments: [reference("account")]))
                        )
                    ],
                    result: .call(Call(selector: "app.add1", arguments: [.literal(.int(1))]))
                )
            ]
        )
        let compiled = try await builder.compile([bank, try adding(1), sending] + Module.standard)

        // When / Then. Laid without the document declaring `app.add1`.
        #expect {
            try builder.lay([compiled[0], compiled[2]] + compiled[3...], supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("'app.add1' is sent by this document, and no document laid beside it declares one")
        }
    }

    @Test("two objects declaring one name are refused where they meet")
    func twoObjectsDeclaringOneNameAreRefused() async throws {
        // Given. Two documents compiled apart, so neither compile saw the
        // other's declarations.
        let baked = try await builder.compile(Module.standard)
        let one = try await builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))
        let two = try await builder.compile([try adding(2)], against: baked, supplying: Supplying(Module.standard))

        // When / Then. The table a link makes has no answer for the name, so
        // it is refused rather than answered by whichever was laid down last.
        #expect {
            try builder.link(baked + one + two, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("'app.add1' is declared by")
                && "\(error)".contains("Two declarations of a name have no way to be told apart")
        }
    }

    @Test("two objects declaring one name are refused where a compile lays them down, in either order")
    func twoObjectsDeclaringOneNameAreRefusedWhereLaid() async throws {
        // Given. Two documents compiled apart that declare one name, each
        // answering a different type.
        let baked = try await builder.compile(Module.standard)
        let one = try await builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))
        let two = try await builder.compile([try adding(2)], against: baked, supplying: Supplying(Module.standard))

        // When / Then. A compile against both is refused whichever the host
        // listed first: the table has no answer for the name either way.
        for held in [baked + one + two, baked + two + one] {
            await #expect {
                try await builder.compile(
                    [try reaching("app.add1")],
                    against: held,
                    supplying: Supplying(Module.standard)
                )
            } throws: { error in
                "\(error)".contains("'app.add1' is declared by")
                    && "\(error)".contains("Two declarations of a name have no way to be told apart")
            }
        }
    }

    @Test("a refusal counts the list the host handed over")
    func aRefusalCountsTheHostsList() async throws {
        // Given. A vocabulary already compiled, so what arrives stands after
        // it. The two arriving documents are the vocabulary's count and one
        // past it.
        let baked = try await builder.compile(Module.standard)
        let first = "the module at \(baked.count) in this link"
        let second = "the module at \(baked.count + 1) in this link"

        // When / Then. Two arriving documents colliding with each other.
        await #expect {
            try await builder.compile([try adding(1), try adding(2)], against: baked, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }

        // And one colliding with a document already compiled, which counts
        // from the same place.
        await #expect {
            try await builder.compile(
                [try adding(2)],
                against: baked + (try await builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))),
                supplying: Supplying(Module.standard)
            )
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }
    }

    @Test("a document already compiled is not handed over again")
    func aCompiledDocumentIsNotHandedOverAgain() async throws {
        // Given. A document with an identity, so two copies of it are one
        // document, compiled once.
        let arriving = try Module(
            try Module(procedures: [:]).draft,
            identity: Identity([0x01, 0x02, 0x03])
        )
        let baked = try await builder.compile(Module.standard)
        let compiled = try await builder.compile([arriving], against: baked, supplying: Supplying(Module.standard))

        // When / Then. The same document handed over again is the same
        // document twice, whichever side it arrived on.
        await #expect {
            try await builder.compile([arriving], against: baked + compiled, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("this document was handed to the build twice")
        }
    }

    @Test("a document already compiled is not handed to a link twice")
    func aCompiledDocumentIsNotLinkedTwice() async throws {
        // Given. A document with an identity, compiled once.
        let arriving = try Module(
            try Module(procedures: [:]).draft,
            identity: Identity([0x01, 0x02, 0x03])
        )
        let baked = try await builder.compile(Module.standard)
        let compiled = try await builder.compile([arriving], against: baked, supplying: Supplying(Module.standard))

        // When / Then. Handed twice, it is the same document twice, and it
        // declares nothing a collision could be said about.
        #expect {
            try builder.link(baked + compiled + compiled, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("this document was handed to the build twice")
        }
    }

    @Test("a compiled document names its native procedures and holds none of their code")
    func anObjectHoldsNoNativeCode() async throws {
        // Given / When. The standard vocabulary: its builtin procedures are the
        // host's, and the rest are written in Warp and carry their bodies.
        let baked = try await builder.compile(Module.standard)

        // Then. Every builtin has a row, and each says the code is the host's.
        let builtin = baked.flatMap(\.table).filter { row in Module.builtinProcedures.contains(row.label) }

        #expect(Set(builtin.map(\.label)) == Module.builtinProcedures)

        for row in builtin {
            guard case .native = row.implementation else {
                Issue.record("\(row.label) carries code")
                continue
            }
        }
    }

    @Test("a link handed no native code is refused where the procedure was declared")
    func aLinkWithoutNativeCodeIsRefused() async throws {
        // Given. A vocabulary compiled, and a document compiled against it.
        let baked = try await builder.compile(Module.standard)
        let compiled = try await builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))

        // When / Then. The objects alone say which procedures are native and
        // nothing more, so a link brought none of the code cannot run them.
        #expect {
            try builder.link(baked + compiled, supplying: Supplying([]))
        } throws: { error in
            "\(error)".contains("is implemented in native code and this link was handed none")
        }
    }

    @Test("a procedure brought under a spelling declares what the row was compiled against")
    func aBroughtProcedureDeclaresWhatWasCompiledAgainst() async throws {
        // Given. A document compiled against a procedure saying it touches nothing
        // shared.
        let baked = try await builder.compile([try counting(isolated: true)] + Module.standard)

        // When / Then. Linking with a procedure of the same spelling saying it
        // touches something shared judges the row against a claim nothing in
        // the build makes.
        #expect {
            try builder.link(
                baked,
                supplying: Supplying([try counting(isolated: false)] + Module.standard)
            )
        } throws: { error in
            "\(error)".contains("said about its isolation, and the procedure brought under")
        }
    }

    @Test("a procedure brought under a spelling takes what the row was compiled against")
    func aBroughtProcedureTakesWhatTheRowWasCompiledAgainst() async throws {
        // Given. A document compiled against a procedure reading one argument under
        // 'of'.
        let baked = try await builder.compile([try reading(under: "of")] + Module.standard)

        // When / Then. A procedure of the same spelling reading under another name
        // reads its arguments at places this row does not stand on.
        #expect {
            try builder.link(
                baked,
                supplying: Supplying([try reading(under: "value")] + Module.standard)
            )
        } throws: { error in
            "\(error)".contains("said about its declaration, and the procedure brought under")
        }
    }

    @Test("a spelling two modules bring native code for is refused")
    func aDoubledBroughtSpellingIsRefused() throws {
        // Given / When / Then. Two modules declaring one spelling in native
        // code, handed over together.
        #expect {
            try Supplying([try counting(isolated: true), try counting(isolated: false)])
        } throws: { error in
            "\(error)".contains("'app.counted' is brought by two of the modules handed over")
        }
    }

    @Test("a compile handed no native code stands the procedures it never folds")
    func aCompileStandsWhatItNeverFolds() async throws {
        // Given. A vocabulary compiled, and a document whose bodies call it
        // but whose constants fold through nothing.
        let baked = try await builder.compile(Module.standard)

        // When / Then. What a compile runs is what it folds, so a document
        // folding nothing needs no code behind the procedures it calls.
        await #expect(throws: Never.self) {
            try await builder.compile([try adding(1)], against: baked, supplying: .none)
        }
    }

    @Test("a constant folding through a procedure no code was brought for is refused")
    func aFoldThroughAnUnbroughtQueryIsRefused() async throws {
        // Given. A vocabulary compiled, and a document whose constant runs one
        // of its procedures.
        let baked = try await builder.compile(Module.standard)
        let arriving = try Module(
            imports: ["std.math.plus"],
            constants: [
                "app.two": .call(
                    Call(selector: "std.math.plus", arguments: [.literal(.int(1)), .literal(.int(1))])
                )
            ],
            procedures: [
                "app.main": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: reference("app.two")
                )
            ]
        )

        // When / Then.
        await #expect {
            try await builder.compile([arriving], against: baked, supplying: .none)
        } throws: { error in
            "\(error)".contains("'std.math.plus' is implemented in native code")
                && "\(error)".contains("this compile was handed none")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A document declaring one native procedure reading a single argument under
    // the name given.
    private func reading(under name: Name) throws -> Module {
        try Module(
            procedures: [
                "app.counted": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: name, type: .int)],
                        returns: .int
                    ),
                    implementation: name == "of" ? .query(OfQuery()) : .query(ValueQuery())
                )
            ]
        )
    }

    // A document declaring one native procedure, which says whether it touches
    // anything shared.
    private func counting(isolated: Bool) throws -> Module {
        try Module(
            procedures: [
                "app.counted": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    implementation: .query(CountingQuery(isolated: isolated))
                )
            ]
        )
    }

    // A document calling the one procedure named, handing it a number.
    private func reaching(_ name: Name) throws -> Module {
        try Module(
            imports: [name],
            procedures: [
                "app.main": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: name, arguments: [.literal(.int(1))]))
                )
            ]
        )
    }

    // A document adding a number to what it is sent, through the vocabulary.
    private func adding(_ number: Int, called name: Name = "app.add1") throws -> Module {
        try Module(
            imports: ["std.math.plus"],
            procedures: [
                name: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "value", type: .int)], returns: .int),
                    body: [],
                    result: .call(
                        Call(
                            selector: "std.math.plus",
                            arguments: [.reference([.key("value")]), .literal(.int(number))]
                        )
                    )
                )
            ]
        )
    }
}

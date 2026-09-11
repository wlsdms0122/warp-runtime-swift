//
//  BakedTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Testing
@testable import Warp
@testable import WarpStandard

@Suite("A caller compiles documents once and links them many times")
struct BakedTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Test
    @Test("a vocabulary compiled once answers a document that arrives after it")
    func aBakedVocabularyAnswersALaterDocument() async throws {
        // Given. The standard vocabulary compiled on its own, the way a host
        // that means to link many documents against it compiles it once.
        let baked = try builder.compile(Module.standard)
        let arriving = try adding(1)

        // When. The document that arrives is the only one compiled.
        let image = try builder.link(
            baked + (try builder.compile([arriving], against: baked, supplying: Supplying(Module.standard))),
            entry: entry,
            supplying: Supplying(Module.standard)
        )

        // Then. It runs, and answers what the same world linked whole answers.
        let whole = try builder.build(Module.standard + [arriving], entry: entry)

        #expect(try await Executor().run(image, arguments: ["value": .int(41)]) == .int(42))
        #expect(try await Executor().run(whole, arguments: ["value": .int(41)]) == .int(42))
    }

    @Test("documents compiled together are ordered by what they reach")
    func documentsAreOrderedByWhatTheyReach() async throws {
        // Given. Two documents handed over with the one that reaches the other
        // first, which is the order a caller has no way to sort out.
        let reaching = try Module(
            imports: ["app.add1"],
            procedures: [
                "app.twice": Procedure(
                    signature: Signature(parameters: ["value": Parameter(type: .int)], returns: .int),
                    body: [
                        Statement(
                            binding: .constant("once"),
                            expression: .call(
                                Call(selector: "app.add1", arguments: ["value": .reference([.key("value")])])
                            )
                        )
                    ],
                    result: .call(Call(selector: "app.add1", arguments: ["value": reference("once")]))
                )
            ]
        )

        // When.
        let baked = try builder.compile(Module.standard)
        let compiled = try builder.compile(
            [reaching, try adding(1, called: "app.add1")],
            against: baked,
            supplying: Supplying(Module.standard)
        )
        let image = try builder.link(baked + compiled, entry: "app.twice", supplying: Supplying(Module.standard))

        // Then.
        #expect(try await Executor().run(image, arguments: ["value": .int(40)]) == .int(42))
    }

    @Test("a word nothing compiled answers is refused where it is sent")
    func aWordNothingAnswersIsRefused() throws {
        // Given. A document sending a word neither it nor the vocabulary
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
        #expect {
            try builder.compile(
                [arriving],
                against: try builder.compile(Module.standard),
                supplying: Supplying(Module.standard)
            )
        } throws: { error in
            "\(error)".contains("'app.missing', which no module in this link declares")
        }
    }

    @Test("two artifacts declaring one name are refused where they meet")
    func twoArtifactsDeclaringOneNameAreRefused() throws {
        // Given. Two documents compiled apart, so neither compile saw the
        // other's declarations.
        let baked = try builder.compile(Module.standard)
        let one = try builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))
        let two = try builder.compile([try adding(2)], against: baked, supplying: Supplying(Module.standard))

        // When / Then. The table a link makes has no answer for the name, so
        // it is refused rather than answered by whichever was laid down last.
        #expect {
            try builder.link(baked + one + two, entry: entry, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("'app.add1' is declared by")
                && "\(error)".contains("Two declarations of a name have no way to be told apart")
        }
    }

    @Test("a refusal counts the list the caller handed over")
    func aRefusalCountsTheCallersList() throws {
        // Given. A vocabulary already compiled, so what arrives stands after
        // it. The two arriving documents are the vocabulary's count and one
        // past it.
        let baked = try builder.compile(Module.standard)
        let first = "the module at \(baked.count) in this link"
        let second = "the module at \(baked.count + 1) in this link"

        // When / Then. Two arriving documents colliding with each other.
        #expect {
            try builder.compile([try adding(1), try adding(2)], against: baked, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }

        // And one colliding with a document already compiled, which counts
        // from the same place.
        #expect {
            try builder.compile(
                [try adding(2)],
                against: baked + (try builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))),
                supplying: Supplying(Module.standard)
            )
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }
    }

    @Test("a document already compiled is not handed over again")
    func aCompiledDocumentIsNotHandedOverAgain() throws {
        // Given. A document with an identity, so two copies of it are one
        // document, compiled once.
        let arriving = try Module(
            try Module(procedures: [:]).draft,
            identity: Identity([0x01, 0x02, 0x03])
        )
        let baked = try builder.compile(Module.standard)
        let compiled = try builder.compile([arriving], against: baked, supplying: Supplying(Module.standard))

        // When / Then. The same document handed over again is the same
        // document twice, whichever side it arrived on.
        #expect {
            try builder.compile([arriving], against: baked + compiled, supplying: Supplying(Module.standard))
        } throws: { error in
            "\(error)".contains("this document was handed to the build twice")
        }
    }

    @Test("a compiled document names its native words and holds none of their code")
    func anArtifactHoldsNoNativeCode() throws {
        // Given. The standard vocabulary, which is native the whole way down.
        let baked = try builder.compile(Module.standard)

        // Then. Every row it settled says the code is the host's.
        for document in baked {
            for row in document.table {
                guard case .native = row.implementation else {
                    Issue.record("\(row.label) carries code")
                    continue
                }
            }
        }
    }

    @Test("a link handed no native code is refused where the word was declared")
    func aLinkWithoutNativeCodeIsRefused() throws {
        // Given. A vocabulary compiled, and a document compiled against it.
        let baked = try builder.compile(Module.standard)
        let compiled = try builder.compile([try adding(1)], against: baked, supplying: Supplying(Module.standard))

        // When / Then. The artifacts alone say which words are native and
        // nothing more, so a link brought none of the code cannot run them.
        #expect {
            try builder.link(baked + compiled, entry: entry, supplying: Supplying([]))
        } throws: { error in
            "\(error)".contains("is implemented in native code and this link was handed none")
        }
    }

    @Test("a word brought under a spelling declares what the row was compiled against")
    func aBroughtWordDeclaresWhatWasCompiledAgainst() throws {
        // Given. A document compiled against a word saying it touches nothing
        // shared.
        let baked = try builder.compile([try counting(isolated: true)] + Module.standard)

        // When / Then. Linking with a word of the same spelling saying it
        // touches something shared judges the row against a claim nothing in
        // the build makes.
        #expect {
            try builder.link(
                baked,
                entry: "app.counted",
                supplying: Supplying([try counting(isolated: false)] + Module.standard)
            )
        } throws: { error in
            "\(error)".contains("said about its isolation, and the word brought under")
        }
    }

    @Test("a word brought under a spelling takes what the row was compiled against")
    func aBroughtWordTakesWhatTheRowWasCompiledAgainst() throws {
        // Given. A document compiled against a word reading one argument under
        // 'of'.
        let baked = try builder.compile([try reading(under: "of")] + Module.standard)

        // When / Then. A word of the same spelling reading under another name
        // reads its arguments at places this row does not stand on.
        #expect {
            try builder.link(
                baked,
                entry: "app.counted",
                supplying: Supplying([try reading(under: "value")] + Module.standard)
            )
        } throws: { error in
            "\(error)".contains("said about its declaration, and the word brought under")
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

    @Test("a compile handed no native code stands the words it never folds")
    func aCompileStandsWhatItNeverFolds() throws {
        // Given. A vocabulary compiled, and a document whose bodies call it
        // but whose constants fold through nothing.
        let baked = try builder.compile(Module.standard)

        // When / Then. What a compile runs is what it folds, so a document
        // folding nothing needs no code behind the words it calls.
        #expect(throws: Never.self) {
            try builder.compile([try adding(1)], against: baked, supplying: .none)
        }
    }

    @Test("a constant folding through a word no code was brought for is refused")
    func aFoldThroughAnUnbroughtWordIsRefused() throws {
        // Given. A vocabulary compiled, and a document whose constant runs one
        // of its words.
        let baked = try builder.compile(Module.standard)
        let arriving = try Module(
            imports: ["std.math.plus"],
            constants: [
                "app.two": .call(
                    Call(
                        selector: "std.math.plus",
                        arguments: ["of": .literal(.int(1)), "value": .literal(.int(1))]
                    )
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
        #expect {
            try builder.compile([arriving], against: baked, supplying: .none)
        } throws: { error in
            "\(error)".contains("'std.math.plus' is implemented in native code")
                && "\(error)".contains("this compile was handed none")
        }
    }

    // MARK: - Private
    private var entry: Name { "app.add1" }

    // A document declaring one native word reading a single argument under
    // the name given.
    private func reading(under name: Name) throws -> Module {
        try Module(
            procedures: [
                "app.counted": Procedure(
                    signature: Signature(
                        parameters: [name: Parameter(type: .int)],
                        returns: .int
                    ),
                    implementation: name == "of" ? .query(OfQuery()) : .query(ValueQuery())
                )
            ]
        )
    }

    // A document declaring one native word, which says whether it touches
    // anything shared.
    private func counting(isolated: Bool) throws -> Module {
        try Module(
            procedures: [
                "app.counted": Procedure(
                    signature: Signature(returns: .int),
                    implementation: .query(CountingQuery(isolated: isolated))
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
                    signature: Signature(parameters: ["value": Parameter(type: .int)], returns: .int),
                    body: [],
                    result: .call(
                        Call(
                            selector: "std.math.plus",
                            arguments: [
                                "of": .reference([.key("value")]),
                                "value": .literal(.int(number))
                            ]
                        )
                    )
                )
            ]
        )
    }
}

// A word answering a number, which says whether it touches anything shared.
private struct CountingQuery: Query {
    typealias Parameters = NoParameters

    // MARK: - Property
    let isolated: Bool

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        .int(1)
    }

    // MARK: - Private
}

// Two words answering the same way, each reading its one argument under its
// own name.
private struct OfQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .int) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        question[.of]
    }

    // MARK: - Private
}

private struct ValueQuery: Query {
    enum Parameters: Int, ParameterSet {
        case value

        var name: Name { "value" }

        var declared: Parameter { Parameter(type: .int) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        question[.value]
    }

    // MARK: - Private
}

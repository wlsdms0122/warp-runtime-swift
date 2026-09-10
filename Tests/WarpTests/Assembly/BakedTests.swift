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
    private let linker = Linker()

    // MARK: - Test
    @Test("a vocabulary compiled once answers a document that arrives after it")
    func aBakedVocabularyAnswersALaterDocument() async throws {
        // Given. The standard vocabulary compiled on its own, the way a host
        // that means to link many documents against it compiles it once.
        let baked = try linker.compile(Module.standard)
        let arriving = try adding(1)

        // When. The document that arrives is the only one compiled.
        let image = try linker.link(
            baked + (try linker.compile([arriving], against: baked, supplying: Module.standard)),
            entry: entry,
            supplying: Module.standard
        )

        // Then. It runs, and answers what the same world linked whole answers.
        let whole = try linker.link(Module.standard + [arriving], entry: entry)

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
        let baked = try linker.compile(Module.standard)
        let compiled = try linker.compile(
            [reaching, try adding(1, called: "app.add1")],
            against: baked,
            supplying: Module.standard
        )
        let image = try linker.link(baked + compiled, entry: "app.twice", supplying: Module.standard)

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
            try linker.compile(
                [arriving],
                against: try linker.compile(Module.standard),
                supplying: Module.standard
            )
        } throws: { error in
            "\(error)".contains("'app.missing', which no module in this link declares")
        }
    }

    @Test("two artifacts declaring one name are refused where they meet")
    func twoArtifactsDeclaringOneNameAreRefused() throws {
        // Given. Two documents compiled apart, so neither compile saw the
        // other's declarations.
        let baked = try linker.compile(Module.standard)
        let one = try linker.compile([try adding(1)], against: baked, supplying: Module.standard)
        let two = try linker.compile([try adding(2)], against: baked, supplying: Module.standard)

        // When / Then. The table a link makes has no answer for the name, so
        // it is refused rather than answered by whichever was laid down last.
        #expect {
            try linker.link(baked + one + two, entry: entry, supplying: Module.standard)
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
        let baked = try linker.compile(Module.standard)
        let first = "the module at \(baked.count) in this link"
        let second = "the module at \(baked.count + 1) in this link"

        // When / Then. Two arriving documents colliding with each other.
        #expect {
            try linker.compile([try adding(1), try adding(2)], against: baked, supplying: Module.standard)
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }

        // And one colliding with a document already compiled, which counts
        // from the same place.
        #expect {
            try linker.compile(
                [try adding(2)],
                against: baked + (try linker.compile([try adding(1)], against: baked, supplying: Module.standard)),
                supplying: Module.standard
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
        let baked = try linker.compile(Module.standard)
        let compiled = try linker.compile([arriving], against: baked, supplying: Module.standard)

        // When / Then. The same document handed over again is the same
        // document twice, whichever side it arrived on.
        #expect {
            try linker.compile([arriving], against: baked + compiled, supplying: Module.standard)
        } throws: { error in
            "\(error)".contains("this document was handed to the link twice")
        }
    }

    @Test("a compiled document names its native words and holds none of their code")
    func anArtifactHoldsNoNativeCode() throws {
        // Given. The standard vocabulary, which is native the whole way down.
        let baked = try linker.compile(Module.standard)

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
        let baked = try linker.compile(Module.standard)
        let compiled = try linker.compile([try adding(1)], against: baked, supplying: Module.standard)

        // When / Then. The artifacts alone say which words are native and
        // nothing more, so a link brought none of the code cannot run them.
        #expect {
            try linker.link(baked + compiled, entry: entry, supplying: [])
        } throws: { error in
            "\(error)".contains("is implemented in native code and this link was handed none")
        }
    }

    @Test("a word brought under a spelling declares what the row was compiled against")
    func aBroughtWordDeclaresWhatWasCompiledAgainst() throws {
        // Given. A document compiled against a word saying it touches nothing
        // shared.
        let baked = try linker.compile([try counting(isolated: true)] + Module.standard)

        // When / Then. Linking with a word of the same spelling saying it
        // touches something shared judges the row against a claim nothing in
        // the link makes.
        #expect {
            try linker.link(
                baked,
                entry: "app.counted",
                supplying: [try counting(isolated: false)] + Module.standard
            )
        } throws: { error in
            "\(error)".contains("said about its isolation, and the word brought under")
        }
    }

    // MARK: - Private
    private var entry: Name { "app.add1" }

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

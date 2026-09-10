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
            baked + (try linker.compile([arriving], against: baked)),
            entry: entry
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
            against: baked
        )
        let image = try linker.link(baked + compiled, entry: "app.twice")

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
            try linker.compile([arriving], against: try linker.compile(Module.standard))
        } throws: { error in
            "\(error)".contains("'app.missing', which no module in this link declares")
        }
    }

    @Test("two artifacts declaring one name are refused where they meet")
    func twoArtifactsDeclaringOneNameAreRefused() throws {
        // Given. Two documents compiled apart, so neither compile saw the
        // other's declarations.
        let baked = try linker.compile(Module.standard)
        let one = try linker.compile([try adding(1)], against: baked)
        let two = try linker.compile([try adding(2)], against: baked)

        // When / Then. The table a link makes has no answer for the name, so
        // it is refused rather than answered by whichever was laid down last.
        #expect {
            try linker.link(baked + one + two, entry: entry)
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
            try linker.compile([try adding(1), try adding(2)], against: baked)
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }

        // And one colliding with a document already compiled, which counts
        // from the same place.
        #expect {
            try linker.compile(
                [try adding(2)],
                against: baked + (try linker.compile([try adding(1)], against: baked))
            )
        } throws: { error in
            "\(error)".contains(first) && "\(error)".contains(second)
        }
    }

    // MARK: - Private
    private var entry: Name { "app.add1" }

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

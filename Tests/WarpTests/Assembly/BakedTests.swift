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

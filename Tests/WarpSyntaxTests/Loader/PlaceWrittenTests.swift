//
//  PlaceWrittenTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/1/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// A refusal about a document, addressed in the document's own keys.
//
// The language names its slots for itself, which is the right answer for a
// caller that assembled a program in Swift and wrote no text. Here there is a
// text and the author is holding it: `condition` is a slot they cannot look
// for, and `where` is what they typed.
@Suite("A place reads in the keys the document writes")
struct PlaceWrittenTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a refusal from the checking is addressed in the document's keys")
    func aCheckingRefusalIsSpelledForTheAuthor() {
        // Given / When. A loop whose condition reads a name nothing declares.
        // The language calls that slot a condition and this document writes it
        // `where`.
        let error = #expect(throws: ValidationError.self) {
            try loader.loadProcedure([
                "body": [
                    [
                        "let": "spin",
                        "value": ["loop": [
                            "while": ["ref": "missing"],
                            "body": []
                        ]
                    ]]
                ]
            ])
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.spin[0].loop.while")
    }

    @Test("a conditional and a loop hold one slot and write two keys")
    func oneSlotIsWrittenTwoWays() {
        // Given. The language calls both a condition, so the key a place reads
        // with is decided by the construct the walk is inside.
        let conditional = Place.procedure(entryName.spelling, in: .assembled)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .part(.condition(of: .conditional))

        let loop = Place.procedure(entryName.spelling, in: .assembled)
            .statement("spin", at: 0)
            .appending(.construct(.loop))
            .part(.condition(of: .loop))

        // When / Then
        #expect(conditional.written(by: .standard).rendered?.hasSuffix(".conditional.when") == true)
        #expect(loop.written(by: .standard).rendered?.hasSuffix(".loop.while") == true)

        // And the language's own reading says one thing for both
        #expect(conditional.rendered?.hasSuffix(".conditional.condition") == true)
        #expect(loop.rendered?.hasSuffix(".loop.condition") == true)
    }

    @Test("a respelled construct reads as the key its author wrote")
    func aRespelledConstructIsSpelledAsRegistered() throws {
        // Given. A notation that registers the conditional form under another key.
        // What an author may look for in their file is that key, and nothing
        // here holds a second copy of it to disagree with.
        let registry = try ConstructRegistry(forms: ["if": ConditionalForm.self])
        let sut = Place.procedure(entryName.spelling, in: .assembled)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .part(.condition(of: .conditional))

        // When / Then
        #expect(sut.written(by: registry).rendered?.hasSuffix(".if.when") == true)
    }

    @Test("a link refusal reads in the document's keys where a reader is asked for it")
    func aLinkRefusalIsSpelledForTheAuthor() async throws {
        // Given. The stage that has no document of its own. What to link is the
        // caller's statement, so a link cannot know which text a module came
        // out of; the side that read the text can say.
        let module = try loader.loadProcedure([
            "body": [
                [
                    "let": "sent",
                    "value": ["call": ["procedure": "nowhere", "arguments": [1]]
                ]]
            ]
        ], importing: ["nowhere"])

        // When
        let error = await #expect(throws: BuildError.self) {
            try await loader.reading { try await Builder().build([module]) }
        }

        // Then. `call` is the key the author wrote, and `call` is what the
        // language calls the construct
        #expect(error?.place?.rendered == "procedures.entry.body.sent[0].call")

        // And unasked, the language answers in its own terms
        let untranslated = await #expect(throws: BuildError.self) {
            try await Builder().build([module])
        }

        #expect(untranslated?.place?.rendered == "procedures.entry.body.sent[0].call")
    }

    @Test("a construct in a slot no statement holds is still spelled for its own construct")
    func aSlotOutsideAStatementKnowsItsOwner() throws {
        // Given / When. A loop standing in a block's result. Nothing puts a
        // construct step in front of it, so a reading that asked the steps
        // around it would call a loop's condition `when`.
        let error = #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .loop(
                            while: .reference([.key("missing")]),
                            body: Block(body: []),
                            round: "spin"
                        )
                    )
                ]
            )
        }

        // Then
        let place = try #require(error?.place)

        #expect(place.rendered == "procedures.entry.result.condition")
        #expect(place.written(by: .standard).rendered == "procedures.entry.result.while")
    }

    // MARK: - Public
    // MARK: - Private
}

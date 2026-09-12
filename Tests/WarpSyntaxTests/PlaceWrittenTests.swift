//
//  PlaceWrittenTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver
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
@Suite("A place reads in the procedures the document writes")
struct PlaceWrittenTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a refusal from the checking is addressed in the document's keys")
    func aCheckingRefusalIsSpelledForTheAuthor() {
        // Given. A loop whose condition reads a name nothing declares. The
        // language calls that slot a condition and this document writes it
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
        // Given. The language calls both a condition, so the procedure a place reads
        // with is decided by the construct the walk is inside.
        let conditional = Place.procedure(entryName.spelling, in: .assembled)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .part(.condition(of: .conditional))

        let loop = Place.procedure(entryName.spelling, in: .assembled)
            .statement("spin", at: 0)
            .appending(.construct(.loop))
            .part(.condition(of: .loop))

        // Then
        #expect(conditional.written(by: .standard).rendered?.hasSuffix(".conditional.when") == true)
        #expect(loop.written(by: .standard).rendered?.hasSuffix(".loop.while") == true)

        // And the language's own reading says one thing for both
        #expect(conditional.rendered?.hasSuffix(".conditional.condition") == true)
        #expect(loop.rendered?.hasSuffix(".loop.condition") == true)
    }

    @Test("a respelled construct reads as the procedure its author wrote")
    func aRespelledConstructIsSpelledAsRegistered() throws {
        // Given. A notation that registers the conditional form under another procedure.
        // What an author may look for in their file is that procedure, and nothing
        // here holds a second copy of it to disagree with.
        let registry = try ConstructRegistry(forms: ["if": ConditionalForm.self])
        let sut = Place.procedure(entryName.spelling, in: .assembled)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .part(.condition(of: .conditional))

        // Then
        #expect(sut.written(by: registry).rendered?.hasSuffix(".if.when") == true)
    }

    @Test("a link refusal reads in the document's keys where a reader is asked for it")
    func aLinkRefusalIsSpelledForTheAuthor() throws {
        // Given. The stage that has no document of its own. What to link is the
        // caller's statement, so a link cannot know which text a module came
        // out of; the side that read the text can say.
        let module = try loader.loadProcedure([
            "body": [
                [
                    "let": "sent",
                    "value": ["call": ["procedure": "nowhere", "of": 1]
                ]]
            ]
        ], importing: ["nowhere"])

        // When
        let error = #expect(throws: BuildError.self) {
            try loader.reading { try Builder().build([module], entry: entryName) }
        }

        // Then. `call` is the key the author wrote, and `call` is what the
        // language calls the construct
        #expect(error?.place?.rendered == "procedures.entry.body.sent[0].call")

        // And unasked, the language answers in its own terms
        let untranslated = #expect(throws: BuildError.self) {
            try Builder().build([module], entry: entryName)
        }

        #expect(untranslated?.place?.rendered == "procedures.entry.body.sent[0].call")
    }

    @Test("a call and an invocation are written under the same two keys")
    func oneKeyAnswersForBothForms() {
        // Given. The place reading takes both from `CallForm`, which is right
        // only while the two agree. If they ever part, this is what says so
        // rather than a line number quietly going missing.
        #expect(
            CallForm.CodingKeys.procedure.stringValue
                == ApplyForm.CodingKeys.procedure.stringValue
        )
        #expect(
            CallForm.CodingKeys.arguments.stringValue
                == ApplyForm.CodingKeys.arguments.stringValue
        )
    }

    @Test("a construct in a slot no statement holds is still spelled for its own construct")
    func aSlotOutsideAStatementKnowsItsOwner() throws {
        // Given. A loop standing in a block's result. Nothing puts a construct
        // step in front of it, so a reading that asked the steps around it
        // would call a loop's condition `when`.
        let error = #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    entryName: Procedure(
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

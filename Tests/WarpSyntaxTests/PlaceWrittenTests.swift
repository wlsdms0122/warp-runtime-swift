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

// A refusal about a document, addressed in the document's own words.
//
// The language names its slots for itself, which is the right answer for a
// caller that assembled a program in Swift and wrote no text. Here there is a
// text and the author is holding it: `condition` is a slot they cannot look
// for, and `where` is what they typed.
@Suite("A place reads in the words the document writes")
struct PlaceWrittenTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a refusal from the checking is addressed in the document's keys")
    func aCheckingRefusalIsSpelledForTheAuthor() {
        // Given — a loop whose condition reads a name nothing declares. The
        // language calls that slot a condition and this document writes it
        // `where`.
        let error = #expect(throws: ValidationError.self) {
            try loader.loadProcedure([
                "body": [
                    [
                        "id": "spin",
                        "loop": [
                            "where": ["ref": "missing"],
                            "body": []
                        ]
                    ]
                ]
            ])
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.spin[0].loop.where")
    }

    @Test("a branch and a loop hold one slot and write two words")
    func oneSlotIsWrittenTwoWays() {
        // Given — the language calls both a condition, so the word a place
        // reads with is decided by the construct the walk is inside.
        let branch = Place.procedure(entryName, in: .assembled)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .slot(.condition)

        let loop = Place.procedure(entryName, in: .assembled)
            .statement("spin", at: 0)
            .appending(.construct(.loop))
            .slot(.condition)

        // Then
        #expect(branch.written(by: .standard).rendered?.hasSuffix(".branch.when") == true)
        #expect(loop.written(by: .standard).rendered?.hasSuffix(".loop.where") == true)

        // And the language's own reading says one thing for both
        #expect(branch.rendered?.hasSuffix(".conditional.condition") == true)
        #expect(loop.rendered?.hasSuffix(".loop.condition") == true)
    }

    @Test("a respelled construct reads as the word its author wrote")
    func aRespelledConstructIsSpelledAsRegistered() throws {
        // Given — a notation that registers the branch form under another
        // word. What an author may look for in their file is that word, and
        // nothing here holds a second copy of it to disagree with.
        let registry = try ConstructRegistry(forms: ["if": BranchForm.self])
        let sut = Place.procedure(entryName, in: .assembled)
            .statement("pick", at: 0)
            .appending(.construct(.conditional))
            .slot(.condition)

        // Then
        #expect(sut.written(by: registry).rendered?.hasSuffix(".if.when") == true)
    }

    // MARK: - Public
    // MARK: - Private
}

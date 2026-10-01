//
//  ReadingErrorTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

@Suite
struct ReadingErrorTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let identity = Identity(Array(repeating: 0xab, count: 32))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document refused while being read says which document it was")
    func aReadingSaysWhichDocument() throws {
        // Given. A host reading four documents into one link holds the only
        // answer to which file to open, and a refusal that names none sends it
        // opening all four
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "sent", "var": "again", "value": 1]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
    }

    @Test("a document refused for what it says about itself says which document it was")
    func aCheckSaysWhichDocument() throws {
        // Given. The same answer is owed by the refusals that come from making
        // the module rather than from reading it, since a host holding four
        // files cannot tell which stage refused and still has to open one
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "sent", "value": ["call": ["procedure": "std.math.plus"]]]]]]
        ]

        // When
        let error = #expect(throws: ValidationError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
    }

    @Test("the steps of a reading's refusal are the document's own keys")
    func aReadingWalksTheDocumentsKeys() throws {
        // Given. The address decoding reached, spelled the way every other
        // stage spells one, so an author follows the same keys either way: a
        // statement wears the name it wrote, which is what validation and the
        // link call it
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "broken", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.rendered == "abababababab/procedures.entry.body.broken[0].fallbck")
    }

    @Test("a declared name that reads as a number is a key and not a position")
    func aNumericNameIsAKey() throws {
        // Given. A coding key made for a dictionary carries the number its
        // spelling parses to, and `procedures[12]` is an address no document
        // has: what the document holds where the walk is settles which it is
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["12": ["body": [["let": "broken", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.12.body.broken[0].fallbck")
    }

    @Test("a statement that writes an empty name is a statement with no name")
    func anEmptyStatementNameIsNoName() throws {
        // Given. The two ways of writing nothing spell the same, and a step
        // rendering an empty name puts a dot in front of nothing
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "", "value": "x", "fallbck": "y"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body[0].fallbck")
    }

    @Test("a form that refuses in its own terms still says which document")
    func aFormsOwnRefusalIsPlaced() throws {
        // Given. A form reading an expression refuses with the expression
        // reader's own error, which carries no place of its own. It leaves
        // through the door that says every reading is placed, so it is.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["value": ["return": ["record": [1]]]]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
        #expect(error?.place?.rendered == "abababababab/procedures.entry.body[0].value.return")
    }

    @Test("a document refused for the list it does not write is refused about itself")
    func aMissingManifestIsAboutTheDocument() throws {
        // Given. Nothing inside the document is wrong, so there is no step to
        // walk and the document alone is the whole address
        let fixture: Value = [
            "warp": 1,
            "procedures": ["entry": ["result": "hello"]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: identity)
        }

        // Then
        #expect(error?.place?.steps.isEmpty == true)
        #expect(error?.description.hasPrefix("abababababab: ") == true)
    }

    @Test("a refusal about a key the document writes is addressed to that key")
    func aRefusalAboutAKeyIsAtThatKey() throws {
        // Given. A place is what a front end turns into a line, so a refusal
        // that stopped at the document while knowing the key would be pointing
        // an author at the first character of their file
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": [:]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "procedures")
    }

    @Test("a document written for another warp is refused at the key that says so")
    func aVersionRefusalIsAtTheVersionKey() throws {
        // Given. The key is written, so there is something to point at. What
        // says no version at all is refused about the document, since nothing
        // is written there to look at.
        let fixture: Value = [
            "warp": 99,
            "procedures": ["entry": ["result": "hello"]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "warp")
    }

    @Test("a statement that names itself twice is called by neither name")
    func anAmbiguouslyNamedStatementWearsNoName() throws {
        // Given. The name on the place and the name in the sentence are read
        // once, in one place. Two readings would let a statement be labelled
        // 'held' by the address of the very refusal saying it is named twice.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "held", "var": "kept", "value": "x"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body[0]")
        #expect(error?.message.contains("at most once") == true)
    }

    @Test("a statement whose name is not text is called by no name")
    func aNameThatIsNotTextIsNoName() throws {
        // Given. What a name has to be is the reading's question and it is
        // answered by refusing. What the statement is called while that happens
        // is this one, and a number is nothing to call it by.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": 12, "value": "x"]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered?.hasPrefix("procedures.entry.body[0]") == true)
    }

    @Test("a reading inside a closure keeps the address it reached")
    func aReadingInsideAClosureKeepsItsAddress() throws {
        // Given. An expression is a walk like any other and it records where it
        // is like any other. A refusal that arrived here with an address and
        // left with the expression's own would be a shallower answer written
        // over a truer one, and the front end says "exact" about whatever it is
        // handed.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [[
                "let": "helper",
                "value": ["closure": ["body": [["let": "inner", "value": "x", "fallbck": "y"]]]]
            ]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(
            error?.place?.rendered
                == "procedures.entry.body.helper[0].value.closure.body.inner[0].fallbck"
        )
    }

    @Test("a reading inside a record says which field it was in")
    func aReadingInsideARecordSaysWhichField() throws {
        // Given. The walk descends by key here and by position in a list, the
        // same two ways every other walk descends, so a record ten fields deep
        // is not answered with the address of the record
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [[
                "let": "held",
                "value": ["record": ["first": "a", "second": ["ref": [1]]]]
            ]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.held[0].value.record.second.ref")
    }

    @Test("a record with two things wrong refuses the same one every time")
    func aRecordRefusesInNameOrder() throws {
        // Given. One line, and the same line twice. A record read in the order
        // a dictionary hands its keys back is read in an order seeded afresh
        // per process, so which of two bad fields an author is sent to would
        // change between runs of the same reader on the same document.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [[
                "let": "held",
                "value": ["record": ["zebra": ["ref": [1]], "alpha": ["ref": [2]]]]
            ]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == "procedures.entry.body.held[0].value.record.alpha.ref")
    }

    @Test("a document that writes its imports as nothing has not written them")
    func importsWrittenAsNothingIsNotADeclaration() throws {
        // Given. The door and the reader ask the same question of the same key.
        // Answering differently is how a list walks past the door as a claim
        // and past the reader as no claim, arriving trusted and never checked,
        // which is the one thing the list exists to prevent.
        let fixture: Value = [
            "warp": 1,
            "imports": .null,
            "procedures": ["entry": ["body": [["let": "sent", "value": ["call": ["procedure": "std.math.plus"]]]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.message.contains("says what it imports") == true)
    }

    @Test("a fragment is refused about no document, and says so by naming none")
    func aFragmentNamesNoDocument() throws {
        // Given / When. What a fragment will be part of is the caller's, and a
        // reader that named a document here would be naming one it was never
        // shown
        let error = #expect(throws: ReadingError.self) {
            try loader.statement(from: ["id": "broken", "value": "x", "fallbck": "y"])
        }

        // Then
        #expect(error?.place?.document == .assembled)
        #expect(error?.description.hasPrefix(":") == false)
    }

    @Test("a refusal about one key stands on that key", arguments: [
        (["access": "open"], "procedures.entry.access"),
        (["bounds": ["T": "array<int>"], "parameters": [["name": "x", "type": "some T"]]], "procedures.entry.bounds.T"),
        (["bounds": ["U": "std.Numeric"]], "procedures.entry.bounds"),
        (["result": ["ref": 5]], "procedures.entry.result.ref"),
        (["result": ["ref": "a[0"]], "procedures.entry.result.ref")
    ] as [(Value, String)])
    func aRefusalStandsOnItsKey(procedure: Value, place: String) {
        // Given
        let fixture: Value = ["warp": 1, "imports": [], "procedures": ["entry": procedure]]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture, identity: nil)
        }

        // Then
        #expect(error?.place?.rendered == place)
    }

    // MARK: - Public
    // MARK: - Private
}

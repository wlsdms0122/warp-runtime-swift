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

@Suite("A reading refusal says where it was")
struct ReadingErrorTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document refused while being read says which document it was")
    func aReadingSaysWhichDocument() throws {
        // Given. A host reading four documents into one link has to know which
        // file to open, and a refusal that names none sends it opening all four
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "sent", "var": "again", "value": 1]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
    }

    @Test("a document refused for what it says about itself says which document it was")
    func aCheckSaysWhichDocument() throws {
        // Given. The same is owed by the refusals that come from making
        // the module rather than from reading it, since a host holding four
        // files cannot tell which stage refused and still has to open one
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "sent", "value": ["call": ["procedure": "Standard.Numeric.plus"]]]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ValidationError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
    }

    @Test("the steps of a reading's refusal are the document's own keys")
    func aReadingWalksTheDocumentsKeys() throws {
        // Given. The address decoding reached, in the keys the document
        // writes and the positions in the lists it writes, which is how
        // `CHECKING.md` names a place and how the build's is named too
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["let": "broken", "value": "x", "fallbck": "y"]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/procedures.entry.body[0].fallbck")
        #expect(error?.place?.value == [.bytes(identity.bytes), ["procedures", "entry", "body", 0, "fallbck"]])
    }

    @Test("a declared name that reads as a number is a key and not a position")
    func aNumericNameIsAKey() throws {
        // Given. A coding key made for a dictionary carries the number its
        // spelling parses to, and `procedures[12]` is an address no document
        // has: what the document holds where the walk is decides which it is
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["12": ["body": [["let": "broken", "value": "x", "fallbck": "y"]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/procedures.12.body[0].fallbck")
    }

    @Test("a statement is placed by its position, whatever it names", arguments: [
        ([["let": "", "value": "x", "fallbck": "y"]], "procedures.entry.body[0].fallbck"),
        ([["let": "held", "var": "kept", "value": "x"]], "procedures.entry.body[0]"),
        ([["let": 12, "value": "x"]], "procedures.entry.body[0].let"),
        ([["var": "r", "value": ["struct": ["a": 5]]], ["set": "r.a", "value": ["ref": 5]]], "procedures.entry.body[1].value.ref")
    ] as [(Value, String)])
    func aStatementIsItsPosition(body: Value, place: String) throws {
        // Given. A document writes a statement as an element of its body, so
        // the place steps to it by position, whatever name it writes, and
        // whether that name reads or not
        let fixture: Value = ["warp": 1, "imports": [], "procedures": ["entry": ["body": body]]]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/\(place)")
    }

    @Test("a form that refuses in its own terms still says which document")
    func aFormsOwnRefusalIsPlaced() throws {
        // Given. A form reading an expression refuses with the expression
        // reader's own error, which carries no place of its own. It leaves
        // through the door that says every reading is placed, so it is.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [["value": ["return": ["struct": [1]]]]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.document.identity == identity)
        #expect(error?.place?.rendered == "\(identity.short)/procedures.entry.body[0].value.return")
    }

    @Test("a document refused for the list it does not write is refused about itself")
    func aMissingImportsListIsAboutTheDocument() throws {
        // Given. Nothing inside the document is wrong, so there is no step to
        // walk and the document alone is the whole address
        let fixture: Value = [
            "warp": 1,
            "procedures": ["entry": ["body": [["value": ["return": "hello"]]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.steps.isEmpty == true)
        #expect(error?.description.hasPrefix("\(identity.short): ") == true)
    }

    @Test("a refusal about a key the document writes is addressed to that key")
    func aRefusalAboutAKeyIsAtThatKey() throws {
        // Given. A place is what points an author at what they wrote, so a
        // refusal that stopped at the document while knowing the key would be
        // pointing them at the first character of their file
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": "entry"
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/procedures")
    }

    @Test("a document written for another warp is refused at the key that says so")
    func aVersionRefusalIsAtTheVersionKey() throws {
        // Given. The key is written, so there is something to point at. What
        // says no version at all is refused about the document, since nothing
        // is written there to look at.
        let fixture: Value = [
            "warp": 99,
            "procedures": ["entry": ["body": [["value": ["return": "hello"]]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/warp")
    }

    @Test("a reading inside a closure keeps the address it reached")
    func aReadingInsideAClosureKeepsItsAddress() throws {
        // Given. An expression is a walk like any other and it records where it
        // is like any other. A refusal that arrived here with an address and
        // left with the expression's own would be a shallower address written
        // over a truer one, and whoever reads the place takes it as exact.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [[
                "let": "helper",
                "value": ["closure": ["body": [["let": "inner", "value": "x", "fallbck": "y"]]]]
            ]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(
            error?.place?.rendered
                == "\(identity.short)/procedures.entry.body[0].value.closure.body[0].fallbck"
        )
    }

    @Test("a reading inside a struct says which field it was in")
    func aReadingInsideAStructSaysWhichField() throws {
        // Given. The walk descends by key here and by position in a list, the
        // same two ways every other walk descends, so a struct ten fields deep
        // is not reported at the address of the struct
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [[
                "let": "held",
                "value": ["struct": ["first": "a", "second": ["ref": [1]]]]
            ]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/procedures.entry.body[0].value.struct.second.ref")
    }

    @Test("a struct with two things wrong refuses the same one every time")
    func aStructRefusesInNameOrder() throws {
        // Given. One line, and the same line twice. A struct read in the order
        // a dictionary hands its keys back is read in an order seeded afresh
        // per process, so which of two bad fields an author is sent to would
        // change between runs of the same reader on the same document.
        let fixture: Value = [
            "warp": 1,
            "imports": [],
            "procedures": ["entry": ["body": [[
                "let": "held",
                "value": ["struct": ["zebra": ["ref": [1]], "alpha": ["ref": [2]]]]
            ]]]]
        ]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/procedures.entry.body[0].value.struct.alpha.ref")
    }

    @Test("a document that writes its imports as nothing has not written them")
    func importsWrittenAsNothingIsNotADeclaration() throws {
        // Given. The door and the reader ask the same question of the same key.
        // Deciding differently is how a list walks past the door as a claim
        // and past the reader as no claim, arriving trusted and never checked,
        // which is the one thing the list exists to prevent.
        let fixture: Value = [
            "warp": 1,
            "imports": .null,
            "procedures": ["entry": ["body": [["let": "sent", "value": ["call": ["procedure": "Standard.Numeric.plus"]]]]]]
        ]

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.message.contains("says what it imports") == true)
    }

    @Test("a refusal about one key stands on that key", arguments: [
        (["access": "open"], "procedures.entry.access"),
        (["parameters": [["name": "x", "type": "some T: "]]], "procedures.entry.parameters[0].type"),
        (["bounds": ["T.Item": ""], "parameters": [["name": "x", "type": "some T"]]], "procedures.entry.bounds.T.Item"),
        (["body": [["value": ["return": ["ref": 5]]]]], "procedures.entry.body[0].value.return.ref"),
        (["body": [["value": ["return": ["ref": "a[0"]]]]], "procedures.entry.body[0].value.return.ref")
    ] as [(Value, String)])
    func aRefusalStandsOnItsKey(procedure: Value, place: String) throws {
        // Given
        let fixture: Value = ["warp": 1, "imports": [], "procedures": ["entry": procedure]]

        let identity = try Identity.of(fixture)

        // When
        let error = #expect(throws: ReadingError.self) {
            try loader.load(fixture)
        }

        // Then
        #expect(error?.place?.rendered == "\(identity.short)/\(place)")
    }

    // MARK: - Public
    // MARK: - Private
}

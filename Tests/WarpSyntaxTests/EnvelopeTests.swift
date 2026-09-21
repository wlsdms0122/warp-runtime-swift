//
//  EnvelopeTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// What a document says about itself before anything reads what it says.
//
// Both questions exist only because a program can arrive somewhere that did not
// build it: is this written for a reader like me, and do I have the procedures it
// calls. A program that stays where it was built has neither question, because
// the thing that built it is the thing that runs it.
//
// And both have to be answerable before it runs. Half-running a program is the
// one outcome worse than refusing it, since what already happened cannot be
// taken back.
@Suite("A document says what it imports before it is read")
struct EnvelopeTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let sut = Writer()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document written for a later reader is refused")
    func aLaterDocumentIsRefused() async {
        // Given. This is the failure the version exists to prevent. Without it
        // a reader meets a type it does not know, reads what it recognises and
        // ignores the rest, and runs a program nobody wrote.
        #expect {
            try loader.load([
                "warp": .int(Envelope.version + 1),
                "procedures": ["entry": ["result": "hello"]]
            ])
        } throws: { error in
            "\(error)".contains("written for warp")
        }

        // And one written for this reader is read
        await #expect(throws: Never.self) {
            try loader.load([
                "warp": .int(Envelope.version),
                "imports": [],
                "procedures": ["entry": ["result": "hello"]]
            ])
        }
    }

    @Test("a document that says nothing is not a document")
    func silenceIsRefused() {
        // Given. A reader that filled in a default here would be answering the
        // one question that has to come from the bytes, and answering it on the
        // sender's behalf. Nobody writes this number by hand; a front end
        // computes it, so a document without one did not come from a front end.
        #expect {
            try loader.load(["procedures": ["entry": ["result": "hello"]]])
        } throws: { error in
            "\(error)".contains("not a warp document")
        }
    }

    @Test("a file of some other type is refused for being one, not for its keys")
    func whatIsNotADocumentIsToldSo() {
        // Given. A conformance case, which is written in the same text and is
        // not a document: it declares `test`, nests the document it asks about,
        // and says what should happen. Without the version being required this
        // would reach the key gate and come back as a malformed module. The
        // same sentence a typo earns, for something that was never a module.
        #expect {
            try loader.load([
                "test": 1,
                "name": "a-case",
                "note": "why it exists",
                "expect": ["answers": 1],
                "program": ["warp": 1, "procedures": ["entry": ["result": "hello"]]]
            ])
        } throws: { error in
            "\(error)".contains("not a warp document")
        }
    }

    @Test("what a document says it imports is what it sends")
    func theManifestIsTheTruth() throws {
        // Given. A caller reads this to decide whether to run the program at
        // all, so a list allowed to drift would be worse than none: it would be
        // trusted and wrong.
        let module = try loader.loadDocument([
            "imports": ["std.math.plus"],
            "procedures": [
                "entry": [
                    "parameters": ["names": ["type": "array<string>"]],
                    "body": [
                        [
                            "let": "many",
                            "value": ["call": ["procedure": "std.math.plus", "of": 1, "arguments": ["value": 2]]
                        ]]
                    ],
                    "result": ["ref": "many"]
                ]
            ]
        ])

        // When
        let written = try sut.value(of: module)

        // Then
        #expect(written[Envelope.importsKey] == .array([.string("std.math.plus")]))
    }

    @Test("a document that says nothing about what it imports is refused")
    func aSilentManifestIsRefused() async {
        // Given. Silence is not a claim a caller can act on. The list is read
        // before the program and a grant is decided from it, so a document that
        // leaves it out is asking to be trusted about the one thing worth
        // checking, and a caller with no list has no way to tell a program that
        // touches nothing from one that touches everything.
        #expect {
            try loader.load([
                "warp": .int(Envelope.version),
                "procedures": ["entry": ["result": "hello"]]
            ])
        } throws: { error in
            "\(error)".contains("says what it imports")
        }

        // And a program that sends nothing still says so, rather than saying
        // nothing. The empty list is a claim and the absent one is not.
        await #expect(throws: Never.self) {
            try loader.load([
                "warp": .int(Envelope.version),
                "imports": [],
                "procedures": ["entry": ["result": "hello"]]
            ])
        }
    }

    @Test("what a document will not even read is what it is refused for")
    func aMalformedDocumentIsRefusedForBeingMalformed() {
        // Given. A document with something else wrong with it and no list
        // either. A missing list is the least specific thing that can be wrong,
        // so going first would make it the only thing an author ever heard
        // about.
        #expect {
            try loader.load([
                "warp": .int(Envelope.version),
                "procedures": ["entry": ["nonsense": "hello"]]
            ])
        } throws: { error in
            "\(error)".contains("says what it imports") == false
        }
    }

    @Test("a document that undersells what it imports is refused")
    func anUntruthfulManifestIsRefused() {
        // Given. The whole value of the list is that it can be believed, and
        // what is said back is the procedure that moved rather than both lists
        #expect {
            try loader.loadDocument([
                "imports": [],
                "procedures": [
                    "entry": [
                        "body": [
                            [
                                "let": "sum",
                                "value": ["call": ["procedure": "std.math.plus", "of": 1, "arguments": ["value": 2]]
                            ]]
                        ],
                        "result": ["ref": "sum"]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("uses [\"std.math.plus\"], which it does not import")
        }
    }

    @Test("a document that oversells what it imports is refused the same way")
    func anOverstatedManifestIsRefused() {
        // Given. The list is the set of what the program sends, not a bound
        // around it: a caller grants from this list, and a procedure listed but
        // never sent is a grant the program had no use for
        #expect {
            try loader.loadDocument([
                "imports": ["std.math.plus", "std.math.minus"],
                "procedures": [
                    "entry": [
                        "body": [
                            [
                                "let": "sum",
                                "value": ["call": ["procedure": "std.math.plus", "of": 1, "arguments": ["value": 2]]
                            ]]
                        ],
                        "result": ["ref": "sum"]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("imports [\"std.math.minus\"], which it does not use")
        }
    }

    @Test("a procedure sent from a constant is imported like any other")
    func constantsSendProceduresToo() throws {
        // Given. A constant is an expression, and understating what a program
        // imports is worse than saying nothing: a caller decides from this list
        // what to allow, and would then be refused at the build by a procedure the
        // list never mentioned.
        let constant: Value = [
            "call": ["procedure": "std.math.plus", "of": 1, "arguments": ["value": 2]]
        ]

        let module = try loader.loadDocument([
            "imports": ["std.math.plus"],
            "const": ["limit": constant],
            "procedures": ["entry": ["result": ["ref": "limit"]]]
        ])

        // Then
        #expect(module.imports == ["std.math.plus"])

        // And a list that leaves the constant's procedure out is refused
        #expect {
            try loader.loadDocument([
                "imports": [],
                "const": ["limit": constant],
                "procedures": ["entry": ["result": ["ref": "limit"]]]
            ])
        } throws: { error in
            "\(error)".contains("uses [\"std.math.plus\"]")
        }
    }

    @Test("a document claiming a version that never existed is refused")
    func aVersionBelowTheEarliestIsRefused() {
        // Given. The range is closed at both ends. Below it, a document claims
        // a language that never was.
        #expect(throws: (any Error).self) {
            try loader.load(["warp": 0, "procedures": ["entry": ["result": "hello"]]])
        }
    }

    @Test("being too old to read a document is not the same as the document being wrong")
    func versionIsCheckedBeforeTheKeys() {
        // Given. A later version may add keys, so checking the type first
        // would turn "I am too old for this" into "this is malformed". The
        // answers differ: one is upgrade me, the other is fix the sender.
        #expect {
            try loader.load([
                "warp": .int(Envelope.version + 1),
                "somethingALaterVersionAdded": "…",
                "procedures": ["entry": ["result": "hello"]]
            ])
        } throws: { error in
            "\(error)".contains("written for warp")
        }
    }

    @Test("a document written for the earliest reader is still read")
    func anEarlierDocumentIsStillRead() throws {
        // Given. The number moved when the language did, and the promise that
        // makes it worth having is that moving it does not lock out what was
        // already written. Backward is a promise; forward is not available to
        // anyone, which is the whole reason the number exists. Nothing has
        // shipped yet, so the two ends of the promise are one number for now.
        let sut = try loader.load([
            "imports": [],
            "warp": .int(Envelope.earliest),
            "procedures": ["entry": ["result": "hello"]]
        ])

        // Then
        #expect(sut.procedures["entry"] != nil)
    }

    @Test("a procedure a document declares itself is not something it imports")
    func ownProceduresAreNotImports() throws {
        // Given. What a document brings with it is not what it asks for
        let module = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "body": [["let": "said", "value": ["call": ["procedure": "greet"]]]],
                    "result": ["ref": "said"]
                ],
                "greet": ["result": "hello"]
            ]
        ])

        // Then
        #expect(module.imports.isEmpty)
    }

    @Test("what a program can do to anything is what it sends")
    func sendingBoundsWhatAProgramReaches() async throws {
        // Given. A path reaches procedures too, and this is why the list can still
        // be read as the bounds of what a program is allowed to do. `count`
        // here is reached by walking rather than sending, and a path only ever
        // reaches a procedure that answers without running, so nothing a path
        // reaches can touch anything outside.
        let module = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "parameters": ["names": ["type": "array<string>"]],
                    "body": [["let": "many", "value": ["ref": "names.count"]]],
                    "result": ["ref": "many"]
                ]
            ]
        ])

        // Then
        #expect(module.imports.isEmpty)

        // And the build still holds it to that. The procedure has to be there
        await #expect(throws: BuildError.self) {
            try await Builder().build([module])
        }
    }

    @Test("a procedure sent from anywhere inside is counted")
    func everyCornerIsCounted() throws {
        // Given. A list that missed one would be a list nobody could rely on,
        // so every place a message can be written is walked
        let module = try loader.loadDocument([
            "imports": ["inClosure", "inLoop", "inBody", "inRescue", "inNestedData"],
            "procedures": [
                "entry": [
                    "parameters": ["names": ["type": "array<string>"]],
                    "body": [
                        [
                            "let": "held",
                            "value": [
                                "closure": ["result": ["call": ["procedure": "inClosure"]]]
                            ]
                        ],
                        [
                            "let": "walked",
                            "value": ["loop": [
                                "while": false,
                                "body": [["let": "seen", "value": ["call": ["procedure": "inLoop"]]]]
                            ]
                        ]],
                        [
                            "let": "tried",
                            "value": ["attempt": [
                                "body": [["let": "risky", "value": ["call": ["procedure": "inBody"]]]],
                                "result": ["ref": "risky"],
                                "rescue": [
                                    "body": [["let": "back", "value": ["call": ["procedure": "inRescue"]]]],
                                    "result": ["ref": "back"]
                                ]
                            ]
                        ]],
                        [
                            "let": "deep",
                            "value": ["a": [["call": ["procedure": "inNestedData"]]]]
                        ]
                    ],
                    "result": ["ref": "tried"]
                ]
            ]
        ])

        // Then
        #expect(
            module.imports
                == ["inClosure", "inLoop", "inBody", "inRescue", "inNestedData"]
        )
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  NotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// The hole a notation is plugged into, and what a document is without one.
//
// The rule these are about is one sentence: **a document has no spellings, and a
// notation's are its own.** Read two ways — a document written plainly needs
// none of them, and a reader given none has no opinion about the keys it meets.
//
// What a particular notation does with the hole — which keys it names, which
// words they reach, what it refuses — is tested where that notation lives.
@Suite("A notation is what a document is read with")
struct NotationTests {
    // MARK: - Property
    private let canonical = Loader(notation: .canonical)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a notation with no spellings owes nothing")
    func spellingNothingLeavesNothingOwed() throws {
        // Given — a canonical notation offers no spellings and registers no
        // construct that lowers to a word, so every shape it can still write is
        // one the language already has, and it owes no vocabulary at all.
        #expect(canonical.vocabulary.isEmpty)
        #expect(!Loader(notation: .testing).vocabulary.isEmpty)
    }

    @Test("a spelling nobody reaches is not owed")
    func aSpellingNobodyReachesIsNotOwed() throws {
        // Given — a condition's words are read through `when` and `where`, so a
        // notation whose spellings reach words and which registers neither form
        // spends nothing on them. Offering is not spending.
        let notation = Notation(
            condition: WordedConditions(),
            interpolation: Interpolation(read: "text", joined: "joined")
        )
        let sut = Loader(registry: try ConstructRegistry(forms: []), notation: notation)

        // Then — what is left is what a template spends, which every slot can
        // hold and no registry decides
        #expect(sut.vocabulary.isDisjoint(with: WordedConditions().vocabulary))
        #expect(sut.vocabulary == notation.vocabulary)
    }

    @Test("what a condition spelling reaches is owed where a condition is read")
    func aConditionsWordsAreOwedByTheFormsThatReadOne() throws {
        // Given — the other half: register a form with a condition slot and the
        // words are owed again. Nothing in this package knows what they are.
        let sut = Loader(
            registry: try ConstructRegistry(forms: [BranchForm.self]),
            notation: Notation(condition: WordedConditions())
        )

        // Then
        #expect(sut.vocabulary == WordedConditions().vocabulary)
    }

    @Test("a canonical notation still writes every condition the language has")
    func canonicalConditionsAreWholeConditions() async throws {
        // Given — this is what makes the spellings a layer rather than a part of
        // the language. Nothing is lost by giving them up; the message a
        // spelling would have stood for is written out instead.
        let sut = try canonical.loadDocument([
            "procedures": [
                "entry": [
                    "parameters": ["word": "string"],
                    "body": [
                        ["var": "pick"],
                        [
                            "branch": [
                                "when": [
                                    "call": [
                                        "procedure": "std.logic.equal",
                                        "of": ["ref": "word"],
                                        "arguments": ["value": "hey"]
                                    ]
                                ],
                                "then": [["set": "pick", "value": "matched"]],
                                "else": [["set": "pick", "value": "missed"]]
                            ]
                        ]
                    ],
                    "result": ["result": ["ref": "pick"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, arguments: ["word": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("matched"))
    }

    @Test("a record a notation does not claim is the expression it is")
    func anUnclaimedRecordIsAnExpression() throws {
        // Given — a condition slot asks for an expression, and a spelling is one
        // way of arriving at one. A record carrying none of the notation's keys
        // never was a condition shape, which is what keeps the spellings
        // optional wherever a condition is asked for.
        let sut = try Loader.testing.loadProcedure([
            "parameters": ["ready": "bool"],
            "body": [
                [
                    "branch": [
                        "when": ["ref": "ready"],
                        "then": [["id": "kept", "value": "yes"]]
                    ]
                ]
            ]
        ])

        // Then
        guard
            case let .body(block) = sut.procedures[entryName]?.implementation,
            case let .conditional(condition, _, _) = block.body.first?.expression
        else {
            Issue.record("a branch reads a condition")

            return
        }

        #expect(condition.referencePath == path("ready"))
    }

    @Test("a record a document may hold plainly is refused where a notation would claim it")
    func aRecordAcquiredByANotationIsRefusedWhereItWouldBeRead() throws {
        // Given — writing and reading are inverses, and a reading side with
        // spellings is a different far side from one without. Written for a
        // notation that recognises a condition by its subject key, this record
        // would come back a message, so it has no document *there* — even though
        // it has one in a document, below.
        let module = Self.branch(on: .record([
            "of": .reference(path("word")),
            "equal": .literal(.string("hey"))
        ]))

        // Then
        #expect {
            try Writer(readBy: .testing).value(of: module)
        } throws: { error in
            "\(error)".contains("read as a form")
        }
    }

    @Test("a record that some notation would read as a condition is still a record")
    func aRecordInAConditionSlotStaysARecord() throws {
        // Given — the same record, written for a document. A document's
        // condition slot is an expression like any other and no notation is
        // reading it back, so the record is data and is written as data.
        let module = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["word": Parameter(type: .bool)]),
                    body: [
                        Statement(expression: .conditional(
                            .record([
                                "of": .reference(path("word")),
                                "equal": .literal(.string("hey"))
                            ]),
                            then: [Statement(expression: .literal(.string("yes")))],
                            else: nil
                        ))
                    ]
                )
            ]
        )

        // When — written, and read back by a reader with no notation at all
        let written = try Writer().value(of: module)
        let read = try canonical.load(written)

        // Then — the same record arrived, rather than a message
        guard
            case let .body(block) = read.procedures[entryName]?.implementation,
            case let .conditional(condition, _, _) = block.body.first?.expression,
            case let .record(fields) = condition
        else {
            Issue.record("a record written in a condition slot reads back as a record")

            return
        }

        #expect(Set(fields.keys) == ["of", "equal"])
    }

    @Test("a template nobody offers is refused, not read as a record")
    func anUnofferedTemplateIsRefused() {
        // Given — the two template keys stay reserved whether or not a notation
        // offers one. Reading them as an ordinary record would make the same
        // document mean one thing here and another in the notation next door,
        // and nothing would say so.
        #expect {
            try canonical.loadDocument([
                "procedures": [
                    "entry": [
                        "parameters": ["word": "string"],
                        "body": [
                            [
                                "id": "line",
                                "value": ["format": "${w}!", "with": ["w": ["ref": "word"]]]
                            ]
                        ]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("does not spell a template")
        }
    }

    @Test("a template is spelled with the words the notation names")
    func aTemplateSpendsTheNotationsWords() throws {
        // Given — which words a template lowers to is the notation's answer, and
        // the reader carries none of its own
        let sut = try Loader.testing.loadProcedure([
            "parameters": ["word": "string"],
            "body": [
                ["id": "line", "value": ["format": "${w}!", "with": ["w": ["ref": "word"]]]]
            ]
        ])

        // Then
        guard
            case let .body(block) = sut.procedures[entryName]?.implementation,
            case let .dispatch(dispatch) = block.body.first?.expression
        else {
            Issue.record("a template is the words that put text together")

            return
        }

        #expect(dispatch.selector == Notation.testing.interpolation?.joined)
    }

    @Test("a form key wins over a notation's condition, in every notation")
    func aFormKeyIsReadAsAFormWhereverItIsWritten() throws {
        // Given — `{ as: <type>, of: <value> }` is a cast, and the form keys are
        // fixed. A notation that recognises its conditions by the subject key
        // sees the `of` and would claim the record; what it made of the `as`
        // beside it would be a message nobody wrote, and the same document would
        // be a cast in one notation and a send in the next.
        let written: Value = [
            "parameters": ["flag": "any"],
            "body": [
                [
                    "branch": [
                        "when": ["as": "bool", "of": ["ref": "flag"]],
                        "then": [["id": "kept", "value": "yes"]]
                    ]
                ]
            ]
        ]

        // Then — both readers arrive at the cast
        for loader in [canonical, .testing] {
            guard
                case let .body(block) = try loader.loadProcedure(written)
                    .procedures[entryName]?.implementation,
                case let .conditional(condition, _, _) = block.body.first?.expression,
                case .cast = condition
            else {
                Issue.record("`as` names a shape to read, whatever else is written beside it")

                return
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
    // One branch around a condition, since a condition slot is a slot rather
    // than something a document holds on its own.
    private static func branch(on condition: Warp.Expression) -> Module {
        Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["word": Parameter(type: .string)]),
                    body: [
                        Statement(expression: .conditional(
                            condition,
                            then: [Statement(expression: .literal(.string("yes")))],
                            else: nil
                        ))
                    ]
                )
            ]
        )
    }
}

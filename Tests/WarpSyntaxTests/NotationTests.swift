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
// The rule these are about is one sentence: **a document has no spellings, and
// a notation's are its own.** Read two ways. A document written plainly needs
// none of them, and a reader given none has no opinion about the keys it meets.
//
// What a particular notation does with the hole (which keys it names, which
// procedures they reach, what it refuses) is tested where that notation lives.
@Suite("A notation is what a document is read with")
struct NotationTests {
    // MARK: - Property
    private let sut = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a notation with no spellings owes nothing")
    func spellingNothingLeavesNothingOwed() throws {
        // Given. A canonical notation offers no spellings and registers no
        // construct that lowers to a procedure, so every type it can still write is
        // one the language already has, and it owes no vocabulary at all.
        #expect(sut.vocabulary(of: .canonical).isEmpty)
        #expect(!sut.vocabulary(of: .testing).isEmpty)
    }

    @Test("what a spelling reaches is owed wherever the notation is read")
    func aSpellingsProceduresAreOwedByTheNotation() throws {
        // Given. A spelling is written in a value slot and every construct has
        // one, so what it reaches is owed whether or not any form is
        // registered. Nothing in this package knows what those procedures are.
        let notation = Notation(
            spelling: OwnVocabularyConditions(),
            interpolation: Interpolation(read: "text", joined: "joined")
        )

        // Then. With no forms at all, and with the standard ones
        for sut in [Loader(registry: try ConstructRegistry(forms: [])), Loader()] {
            #expect(sut.vocabulary(of: notation).isSuperset(of: OwnVocabularyConditions().vocabulary))
            #expect(sut.vocabulary(of: notation) == notation.vocabulary)
        }
    }

    @Test("a canonical notation still writes every condition the language has")
    func canonicalConditionsAreWholeConditions() async throws {
        // Given. This is what makes the spellings a layer rather than a part of
        // the language. Nothing is lost by giving them up; the message a
        // spelling would have stood for is written out instead.
        let module = try await sut.loadDocument([
            "imports": ["std.logic.equal"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "procedure", "type": "string"]],
                    "body": [
                        ["var": "pick"],
                        [
                            "value": ["conditional": [
                                "when": [
                                    "call": [
                                        "procedure": "std.logic.equal",
                                        "arguments": [["ref": "procedure"], "hey"]
                                    ]
                                ],
                                "then": [["set": "pick", "value": "matched"]],
                                "else": [["set": "pick", "value": "missed"]]
                            ]
                        ]]
                    ],
                    "result": ["result": ["ref": "pick"]]
                ]
            ]
        ], from: .canonical)

        // When
        let outputs = try await run(module, arguments: ["procedure": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("matched"))
    }

    @Test("a record a notation does not claim is the expression it is")
    func anUnclaimedRecordIsAnExpression() async throws {
        // Given. A condition slot asks for an expression, and a spelling is one
        // way of arriving at one. A record carrying none of the notation's keys
        // never was a condition type, which is what keeps the spellings
        // optional wherever a condition is asked for.
        let sut = try await Loader.testing.loadProcedure([
            "parameters": [["name": "ready", "type": "bool"]],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["ref": "ready"],
                        "then": [["let": "kept", "value": "yes"]]
                    ]
                ]]
            ]
        ])

        // Then
        guard
            case let .body(block) = sut.procedures[entryName]?.implementation,
            case let .conditional(condition, _, _) = block.body.first?.expression
        else {
            Issue.record("a conditional reads a condition")

            return
        }

        #expect(condition.referencePath == path("ready"))
    }

    @Test("a record a document may hold plainly is refused where a notation would claim it")
    func aRecordAcquiredByANotationIsRefusedWhereItWouldBeRead() throws {
        // Given. Writing and reading are inverses, and a reading side with
        // spellings is a different far side from one without. Written for a
        // notation that recognises a condition by its subject key, this record
        // would come back a message, so it has no document *there*. Even though
        // it has one in a document, below.
        let module = try Self.conditional(on: .record([
            "of": .reference(path("procedure")),
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
    func aRecordInAConditionSlotStaysARecord() async throws {
        // Given. The same record, written for a document. A document's
        // condition slot is an expression like any other and no notation is
        // reading it back, so the record is data and is written as data.
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "procedure", type: .bool)]),
                    body: [
                        Statement(expression: .conditional(
                            .record([
                                "of": .reference(path("procedure")),
                                "equal": .literal(.string("hey"))
                            ]),
                            then: [Statement(expression: .literal(.string("yes")))],
                            else: nil
                        ))
                    ]
                )
            ]
        )

        // When. Written, and read back by a reader with no notation at all
        let written = try Writer().value(of: module)
        let read = try await sut.load(written)

        // Then. The same record arrived, rather than a message
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
        // Given. The two template keys stay reserved whether or not a notation
        // offers one. Reading them as an ordinary record would make the same
        // document mean one thing here and another in the notation next door,
        // and nothing would say so.
        #expect {
            try sut.loadDocument([
                "imports": ["std.text.joined", "std.text.text"],
                "procedures": [
                    "entry": [
                        "parameters": [["name": "procedure", "type": "string"]],
                        "body": [
                            [
                                "let": "line",
                                "value": ["format": "${w}!", "with": ["w": ["ref": "procedure"]]]
                            ]
                        ]
                    ]
                ]
            ], from: .canonical)
        } throws: { error in
            "\(error)".contains("does not spell a template")
        }
    }

    @Test("a template is spelled with the procedures the notation names")
    func aTemplateSpendsTheNotationsProcedures() async throws {
        // Given, which procedures a template lowers to is the notation's answer, and
        // the reader carries none of its own
        let sut = try await Loader.testing.loadProcedure([
            "parameters": [["name": "procedure", "type": "string"]],
            "body": [
                ["let": "line", "value": ["format": "${w}!", "with": ["w": ["ref": "procedure"]]]]
            ]
        ], importing: ["std.text.joined", "std.text.text"])

        // Then
        guard
            case let .body(block) = sut.procedures[entryName]?.implementation,
            case let .call(call) = block.body.first?.expression
        else {
            Issue.record("a template is the procedures that put text together")

            return
        }

        #expect(call.selector == Notation.testing.interpolation?.joined)
    }

    @Test("a form key wins over a notation's condition, in every notation")
    func aFormKeyIsReadAsAFormWhereverItIsWritten() async throws {
        // Given. `{ as: <type>, of: <value> }` is a cast, and the form keys are
        // fixed. A notation that recognises its conditions by the subject key
        // sees the `of` and would claim the record; what it made of the `as`
        // beside it would be a message nobody wrote, and the same document
        // would be a cast in one notation and a send in the next.
        let written: Value = [
            "parameters": [["name": "flag", "type": "any"]],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["as": "bool", "of": ["ref": "flag"]],
                        "then": [["let": "kept", "value": "yes"]]
                    ]
                ]]
            ]
        ]

        // Then. Both readers arrive at the cast
        for notation in [Notation.canonical, .testing] {
            guard
                case let .body(block) = try await sut.loadProcedure(written, from: notation)
                    .procedures[entryName]?.implementation,
                case let .conditional(condition, _, _) = block.body.first?.expression,
                case .cast = condition
            else {
                Issue.record("`as` names a type to read, whatever else is written beside it")

                return
            }
        }
    }

    @Test("reading a document is not a place a notation can reach")
    func readingCarriesNoNotation() async throws {
        // Given. The spelling these tests read with, left unlowered in a
        // document. `load` takes a document, and a document has no spellings,
        // so the record is the expression it is rather than the message some
        // table would have made of it.
        let module = try await sut.load([
            "warp": .int(Envelope.version),
            "imports": [],
            "procedures": [
                "entry": [
                    "parameters": [["name": "procedure", "type": "string"]],
                    "body": [
                        ["let": "asked", "value": ["of": ["ref": "procedure"], "is": "hey"]]
                    ],
                    "result": ["ref": "asked"]
                ]
            ]
        ])

        // Then
        guard
            case let .body(block) = module.procedures[entryName]?.implementation,
            case let .record(fields) = block.body.first?.expression
        else {
            Issue.record("a document read with no notation reads a record as a record")

            return
        }

        #expect(Set(fields.keys) == ["of", "is"])
    }


    // MARK: - Public
    // MARK: - Private
    // One conditional around a condition, since a condition slot is a slot rather
    // than something a document holds on its own.
    private static func conditional(on condition: Warp.Expression) throws -> Module {
        try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "procedure", type: .string)]),
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

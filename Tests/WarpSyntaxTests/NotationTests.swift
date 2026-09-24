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
                    "result": ["record": ["result": ["ref": "pick"]]]
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

    @Test("a record a notation would claim is written under `record` and read back as a record there")
    func aRecordANotationWouldClaimIsWrittenUnderRecord() throws {
        // Given. Writing and reading are inverses, and a reading side with
        // spellings is a different far side from one without. Written bare
        // for a notation that recognises a condition by its subject key, these
        // fields would come back a message. Under `record` they are a record's
        // fields whatever they are called.
        let module = try Self.conditional(on: .record([
            "of": .reference(path("procedure")),
            "equal": .literal(.string("hey"))
        ]))

        // When
        let written = try Writer(readBy: .testing).value(of: module)
        let read = try sut.loadDocument(written, from: .testing)

        // Then
        guard
            case let .array(body)? = written["procedures"]?["entry"]?["body"],
            let condition = body.first?["value"]?["conditional"]?["when"],
            case let .body(block) = read.procedures[entryName]?.implementation,
            case let .conditional(.record(fields), _, _) = block.body.first?.expression
        else {
            Issue.record("a record written for a notation reads back as a record there")

            return
        }

        #expect(condition["record"]?["of"] == Value.dictionary(["ref": .string("procedure")]))
        #expect(Set(fields.keys) == ["of", "equal"])
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

    @Test("a tag wins over a notation's condition, in every notation")
    func aTagIsReadAsItsFormWhereverItIsWritten() async throws {
        // Given. `{ as: { of: <value>, type: <type> } }` is a cast, and the
        // tags are fixed and read before any spelling. A notation that
        // recognises its conditions by the subject key never sees the `of`
        // written inside the cast, so the same document is a cast in every
        // notation rather than a send in some.
        let written: Value = [
            "parameters": [["name": "flag", "type": "any"]],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["as": ["of": ["ref": "flag"], "type": "bool"]],
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
                Issue.record("`as` is a cast in every notation")

                return
            }
        }
    }

    @Test("reading a document is not a place a notation can reach")
    func readingCarriesNoNotation() async throws {
        // Given. The spelling these tests read with, left unlowered in a
        // document. `load` takes a document, and a document has no spellings,
        // so the mapping is not the message some table would have made of it:
        // standing bare it is refused, and under `record` it is a record.
        func document(asking asked: Value) -> Value {
            [
                "warp": .int(Envelope.version),
                "imports": [],
                "procedures": [
                    "entry": [
                        "parameters": [["name": "procedure", "type": "string"]],
                        "body": [
                            ["let": "asked", "value": asked]
                        ],
                        "result": ["ref": "asked"]
                    ]
                ]
            ]
        }
        let spelled: Value = ["of": ["ref": "procedure"], "is": "hey"]

        // When
        let module = try await sut.load(document(asking: ["record": spelled]))

        // Then
        #expect {
            try sut.load(document(asking: spelled))
        } throws: { error in
            "\(error)".contains("a mapping where a value is wanted is one of")
        }
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

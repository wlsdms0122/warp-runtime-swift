//
//  WriterTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// Writing is how a program leaves the machine that built it, so what it promises
// is not that the text comes back the same — it is that the program does. A
// document arrives spelled however its author liked it and is written back in
// the shapes the language actually has, which is why writing twice is the
// question these ask: the first pass says what the program is, and the second
// has to agree.
@Suite("A program can be written back out as a document")
struct WriterTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let sut = Writer()

    // MARK: - Initializer
    // MARK: - Test
    @Test("every construct survives being written and read back", arguments: Self.corpus)
    func writingIsAFixedPoint(_ document: Value) throws {
        // Given
        let once = try sut.value(of: try loader.loadDocument(document))

        // When
        let twice = try sut.value(of: try loader.load(once))

        // Then
        #expect(once == twice)
    }

    @Test("a program nobody wrote a document for still round-trips", arguments: Self.assembled)
    func writingIsAFixedPointForAssembledPrograms(_ module: Module) throws {
        // Given — every other corpus here starts from a document, so what they
        // check is that documents survive. The half this direction exists for is
        // the other one: a program built by hand, which no reader has ever seen
        // and no notation has had a chance to normalise.
        let once = try sut.value(of: module)

        // When
        let twice = try sut.value(of: try loader.load(once))

        // Then
        #expect(once == twice)
    }

    @Test("a canonical document is written back exactly as it was")
    func aCanonicalDocumentIsWrittenBackUnchanged() throws {
        // Given — `canonical` is written in the shapes themselves, so reading it
        // and writing it must arrive at the same document. A fixed point only
        // says the writing settled; this says nothing was left behind, because
        // every slot the language has is written down here and a slot that
        // stopped being written would go missing from the answer.
        let sut = try sut.value(of: try loader.load(Self.canonical))

        // Then
        #expect(sut == Self.canonical)
    }

    @Test("nothing written is spelled", arguments: Self.corpus)
    func nothingWrittenIsSpelled(_ document: Value) throws {
        // Given — the corpus is written with every spelling the notation has.
        // What comes back may use none of them, because a spelling is a rule the
        // reading side would have to implement the same way, and the reading
        // side is somewhere else.
        let written = try sut.value(of: try loader.loadDocument(document))

        // When — the two template keys, which are reserved in every notation.
        // The condition spelling these are read with is recognised by `of`,
        // which is how a message names its receiver everywhere — so it leaves no
        // key here that a survival could be told apart by. A spelling whose key
        // is not also a word is asked about below.
        let spellings: Set<String> = ["format", "with"]

        // Then
        #expect(Self.keys(in: written).isDisjoint(with: spellings))
    }

    @Test("a spelling whose key is nobody's word does not survive being written")
    func aSpelledKeyIsNotWrittenBack() throws {
        // Given — the corpus above cannot answer this. Its notation names the
        // word in the document (`{ of: x, equal: y }`), so a key that survived
        // and a word that was written look the same on the way out. This one
        // spells `holds` and reaches `example.holds`, and the key appears in a
        // document only if the writing side kept a spelling.
        let loader = Loader()
        let module = try loader.loadProcedure([
            "parameters": ["ready": "bool"],
            "body": [
                [
                    "branch": [
                        "when": ["holds": ["ref": "ready"]],
                        "then": [["id": "kept", "value": "yes"]]
                    ]
                ]
            ]
        ], importing: ["example.holds"], from: Notation(condition: WordedConditions()))

        // When
        let written = try sut.value(of: module)

        // Then
        #expect(Self.keys(in: written).isDisjoint(with: WordedConditions().keys))
        #expect(Self.keys(in: written).contains("call"))
    }

    @Test("a written program runs the way the one it came from did")
    func aWrittenProgramRunsTheSame() async throws {
        // Given — a fixed point says the writing settled, not that it kept
        // everything. Running both is what notices a slot dropped on the way out.
        let document: Value = [
            "imports": ["std.logic.equal", "std.text.joined", "std.math.plus", "std.text.text"],
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>", "word": "string"],
                    "body": [
                        ["var": "pick"],
                        [
                            "branch": [
                                "when": ["of": ["ref": "word"], "equal": "hey"],
                                "then": [["set": "pick", "value": "matched"]],
                                "else": [["set": "pick", "value": "missed"]]
                            ]
                        ],
                        ["var": "walked", "value": 0],
                        [
                            "id": "sized",
                            "each": [
                                "in": ["ref": "names"],
                                "body": [
                                    [
                                        "set": "walked",
                                        "call": [
                                            "of": ["ref": "walked"],
                                            "procedure": "std.math.plus",
                                            "arguments": ["value": ["ref": "sized.item.count"]]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "id": "line",
                            "value": [
                                "format": "${word}/${pick}",
                                "with": ["word": ["ref": "word"], "pick": ["ref": "pick"]]
                            ]
                        ]
                    ],
                    "result": [
                        "picked": ["ref": "pick"],
                        "sizes": ["ref": "walked"],
                        "line": ["ref": "line"]
                    ]
                ]
            ]
        ]
        let arguments: [String: Value] = [
            "names": .array([.string("a"), .string("bb")]),
            "word": .string("hey")
        ]

        let original = try loader.loadDocument(document)
        let travelled = try loader.load(try sut.value(of: original))

        // When
        let before = try await run(original, arguments: arguments)
        let after = try await run(travelled, arguments: arguments)

        // Then
        #expect(before == after)
        #expect(before["picked"] == .string("matched"))
        #expect(before["sizes"] == .int(3))
        #expect(before["line"] == .string("hey/matched"))
    }

    @Test("a spelling is written back as the words it stood for")
    func aSpellingIsWrittenPlainly() throws {
        // Given — `{ of: x, <word>: y }` is a spelling, and what it means is a
        // message. Writing keeps the meaning and drops the spelling, which is
        // the whole reason the layers are worth separating.
        let module = try loader.loadProcedure([
            "parameters": ["word": "string"],
            "body": [
                [
                    "branch": [
                        "when": ["of": ["ref": "word"], "equal": "hey"],
                        "then": [["id": "kept", "value": "matched"]]
                    ]
                ]
            ]
        ], importing: ["std.logic.equal"])

        // When
        let written = try sut.value(of: module)

        // Then
        guard
            case let .array(body)? = written["procedures"]?["entry"]?["body"],
            let message = body.first?["branch"]?["when"]?["call"]
        else {
            Issue.record("a branch is written with a condition under `when`")

            return
        }

        // The word the spelling reached, written as the message it always was.
        #expect(message["procedure"] == .string("std.logic.equal"))
        #expect(message["of"]?["ref"] == .string("word"))
        #expect(message["arguments"]?["value"] == .string("hey"))
    }

    @Test("data that would read as a form is written as data")
    func dataThatLooksLikeAFormIsQuoted() throws {
        // Given — a payload with a field called `ref` is not a reference, and
        // writing it bare would make a document that loads into something else
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "payload",
                            expression: .literal(.object(["ref": .string("not-a-path")]))
                        )
                    ]
                )
            ]
        )

        // When
        let written = try sut.value(of: module)
        let read = try loader.load(written)

        // Then
        guard
            case let .body(block) = read.procedures["entry"]?.implementation,
            case let .literal(carried) = block.body.first?.expression
        else {
            Issue.record("a quoted payload is a literal")

            return
        }

        #expect(carried == .object(["ref": .string("not-a-path")]))
    }

    @Test("a notation that gave up a word cannot write what it said")
    func aDroppedWordCannotBeWritten() throws {
        // Given — the registry is what a notation *is*, so a shape whose word it
        // no longer registers is a shape it can no longer write. Answering with
        // the built-in spelling would put a key in the document that reading it
        // back through this same notation would refuse.
        let module = try loader.loadProcedure([
            "body": [
                [
                    "id": "walked",
                    "loop": [
                        "where": false,
                        "body": [["id": "step", "value": 1]]
                    ]
                ]
            ]
        ])
        let narrowed = Writer(registry: ConstructRegistry.standard.removing(LoopForm.key))

        // When / Then
        #expect(throws: WritingError.self) {
            try narrowed.value(of: module)
        }

        // And the same program through a notation that kept the word is fine
        #expect(throws: Never.self) {
            try sut.value(of: module)
        }
    }

    @Test("a bound outside any signature has no document")
    func aBoundOutsideASignatureHasNoDocument() throws {
        // Given — a module's declared type is a procedure type whose slot
        // carries a bound. No procedure declares this signature, so there is
        // no `bounds` surface for the claim to land on — writing the name
        // bare would be a document that reads back meaning something else.
        let bounded = Signature(
            parameters: [
                "item": Parameter(type: .variable(name: "T", constraint: "Scalar"))
            ],
            returns: .bool
        )
        let module = try Module(
            types: ["Predicate": .procedure(bounded, .unstated)],
            procedures: [
                entryName: Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then
        #expect(throws: WritingError.self) {
            try sut.value(of: module)
        }

        // A parameter written on its own refuses too — every surface below
        // the declaring procedure answers the same way, whichever entry the
        // caller came through
        #expect(throws: WritingError.self) {
            try sut.value(of: Parameter(type: .variable(name: "T", constraint: "Scalar")))
        }

        // A bounded variable declared as a type directly refuses the same way
        let variable = try Module(
            types: ["Loose": .variable(name: "T", constraint: "Scalar")],
            procedures: [
                entryName: Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        #expect(throws: WritingError.self) {
            try sut.value(of: variable)
        }

        // And the same claim carried by a procedure's own slot is written —
        // once, as the declaring signature's `bounds`
        let declaring = try Module(
            procedures: [
                entryName: Procedure(
                    signature: bounded,
                    body: [],
                    result: .literal(.bool(true))
                )
            ]
        )

        let written = try sut.value(of: declaring)

        guard
            case let .object(document) = written,
            case let .object(procedures) = document["procedures"],
            case let .object(entry) = procedures[entryName]
        else {
            Issue.record("the module did not write as a document")

            return
        }

        #expect(entry["bounds"] == .object(["T": .string("Scalar")]))

        guard
            case let .object(parameters) = entry["parameters"]
        else {
            Issue.record("the parameters did not write as a record")

            return
        }

        #expect(parameters["item"] == .string("some T"))
    }

    @Test("a construct binding a name its statement did not give has no document")
    func aMisnamedBindingHasNoDocument() throws {
        // Given — a document cannot write this, because the name a loop binds is
        // the name of the statement it is written as. A caller building the
        // language's shapes directly is under no such obligation, so this is
        // reachable and says so rather than writing a document that would load
        // into something else.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "walked",
                            expression: .loop(
                                while: .literal(.bool(false)),
                                body: Block(body: [Statement(id: "step", expression: .literal(.int(1)))]),
                                round: "somethingElse"
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect {
            try sut.value(of: module)
        } throws: { error in
            "\(error)".contains("binds 'somethingElse' inside 'walked'")
        }
    }

    @Test("a word backed by native code has no document")
    func nativeCodeHasNoDocument() throws {
        // Given — what a caller brings is declared where the run is assembled,
        // not carried in the program. Writing its name alone would make a
        // document that loads into a body nobody wrote.
        let module = try Module(procedures: Module.logic.procedures)

        // When / Then
        #expect(throws: WritingError.self) {
            try sut.value(of: module)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Every key anywhere in a document. A spelling is a word, and a word could
    // be written at any depth, so asking whether one survived is asking about
    // the whole of it.
    private static func keys(in value: Value) -> Set<String> {
        switch value {
        case let .array(elements):
            return elements.reduce(into: Set()) { found, element in
                found.formUnion(keys(in: element))
            }

        case let .object(fields):
            return fields.reduce(into: Set(fields.keys)) { found, field in
                found.formUnion(keys(in: field.value))
            }

        default:
            return []
        }
    }

    // Programs built rather than parsed. What they have in common is that no
    // reader made them, so nothing has already forced them into the shapes a
    // document happens to have — which is exactly where a writer goes wrong.
    private static let assembled: [Module] = [
        // Both cast spellings, over both ways a type is written — a name, and
        // the mapping a record is. A type written back as a string it cannot
        // be read from would survive neither direction.
        try! Module(
            namespace: "casting",
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["payload": Parameter(type: .any)]),
                    body: [
                        Statement(
                            id: "named",
                            expression: .cast(
                                .reference([.key("payload")]),
                                as: .record(["count": .int]),
                                optional: false
                            )
                        ),
                        Statement(
                            id: "asked",
                            expression: .cast(
                                .reference([.key("payload")]),
                                as: .array(.string),
                                optional: true
                            )
                        )
                    ],
                    result: .reference([.key("named"), .key("count")])
                )
            ]
        ),
        // Messages nested inside other expressions, deeper than a document's
        // fixed shapes would ever place them
        try! Module(
            namespace: "nested",
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["word": Parameter(type: .string)]),
                    body: [
                        Statement(
                            id: "joined",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .array([
                                        .dispatch(
                                            Dispatch(
                                                receiver: .reference([.key("word")]),
                                                selector: "std.text.text"
                                            )
                                        ),
                                        .literal(.string("!"))
                                    ]),
                                    selector: "std.text.joined"
                                )
                            )
                        ),
                        Statement(
                            id: "held",
                            expression: .record([
                                "line": .reference([.key("joined")]),
                                "size": .dispatch(
                                    Dispatch(
                                        receiver: .reference([.key("word")]),
                                        selector: "std.collection.count"
                                    )
                                )
                            ])
                        )
                    ],
                    result: .reference([.key("held")])
                )
            ]
        ),
        // Data that would read as a form, quoted, and a variable written twice
        try! Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "payload",
                            expression: .literal(
                                .object(["ref": .string("not-a-path"), "deep": .array([
                                    .object(["value": .int(1)])
                                ])])
                            )
                        ),
                        Statement(id: "count", binding: .variable, expression: .literal(.int(0))),
                        Statement(id: "count", binding: .assignment, expression: .literal(.int(1)))
                    ],
                    result: .reference([.key("payload")])
                )
            ]
        )
    ]

    // The document format, written out. Every slot the language has appears
    // here exactly once, in the shapes that stand one to one with it — no
    // spelling stands in for anything.
    //
    // It is a fixture and also the closest thing to a statement of what a
    // document *is*. Something reading this from another language would need to
    // understand exactly what is written here and nothing else.
    private static let canonical: Value = [
        "warp": 1,
        "imports": ["std.logic.notEqual", "std.math.plus"],
        "name": "canonical",
        "description": "one of every shape",
        "types": ["Task": ["done": "bool", "id": "string"]],
        "constraints": ["Scalar": ["int", "string"]],
        "const": ["limit": 10],
        "procedures": [
            "entry": [
                "description": "every construct, once",
                "parameters": [
                    "names": "array<string>",
                    "word": ["type": "string", "default": "hey", "hint": "what to match"],
                    "kind": ["type": "string", "oneOf": ["a", "b"]]
                ],
                "returns": "object<any>",
                "body": [
                    ["id": "list", "value": [1, 2, 3]],
                    ["id": "pair", "value": ["a": ["ref": "word"], "b": 2]],
                    ["id": "quoted", "value": ["value": ["ref": "not-a-path"]]],
                    ["var": "seen", "value": 0],
                    ["id": "indexed", "value": ["ref": "names[0]"]],
                    ["id": "computed", "value": ["ref": "names[seen].count"]],
                    [
                        "id": "walked",
                        "loop": [
                            "where": [
                                "call": [
                                    "procedure": "std.logic.notEqual",
                                    "of": ["ref": "seen"],
                                    "arguments": ["value": 3]
                                ]
                            ],
                            "body": [
                                [
                                    "set": "seen",
                                    "call": [
                                        "procedure": "std.math.plus",
                                        "of": ["ref": "seen"],
                                        "arguments": ["value": 1]
                                    ]
                                ]
                            ],
                            "result": ["ref": "seen"]
                        ]
                    ],
                    ["var": "pick"],
                    [
                        "branch": [
                            "when": ["ref": "kind"],
                            "then": [["set": "pick", "value": "yes"]],
                            "else": [["set": "pick", "value": "no"]]
                        ]
                    ],
                    [
                        "id": "mapped",
                        "each": [
                            "in": ["ref": "names"],
                            "body": [["id": "one", "value": ["ref": "mapped.item"]]]
                        ]
                    ],
                    [
                        "id": "tried",
                        "attempt": [
                            "body": [["id": "risky", "value": 1]],
                            "result": ["ref": "risky"],
                            "rescue": [
                                "body": [["id": "instead", "value": 0]],
                                "result": ["ref": "instead"]
                            ]
                        ]
                    ],
                    ["id": "grouped", "group": ["body": [["id": "inner", "value": 1]]]],
                    [
                        "id": "called",
                        "invoke": [
                            "procedure": [
                                "closure": ["parameters": ["n": "int"], "result": ["ref": "n"]]
                            ],
                            "arguments": ["n": 1]
                        ]
                    ]
                ],
                "result": ["result": ["ref": "pick"]]
            ],
            "typed": [
                "receiver": "of",
                "parameters": [
                    "of": "string",
                    "how": [
                        "type": [
                            "pure procedure": [
                                "receiver": "it",
                                "parameters": ["it": "int"],
                                "returns": "bool"
                            ]
                        ]
                    ],
                    "anything": "procedure",
                    "parameter": "some Element",
                    "bounded": "some T",
                    "shaped": ["type": ["done": "bool", "id": "string"]]
                ],
                "returns": "never",
                "bounds": ["T": "Scalar"],
                "result": ["ref": "of"]
            ]
        ]
    ]

    // One document per shape the language has, written the way a document
    // usually is — spellings and all, since what comes out the far side is the
    // thing under test.
    static let corpus: [Value] = [
        // Literals, references, records, arrays and quoting
        [
            "name": "plain",
            "description": "the shapes that need no name",
            "types": ["Task": ["id": "string", "done": "bool"]],
            "const": ["limit": 10],
            "procedures": [
                "entry": [
                    "parameters": [
                        "word": "string",
                        "counted": ["type": "int", "default": 1, "hint": "how many"],
                        "kind": ["type": "string", "oneOf": ["a", "b"]]
                    ],
                    "returns": "object<any>",
                    "body": [
                        ["id": "list", "value": [1, 2, 3]],
                        ["id": "pair", "value": ["a": ["ref": "word"], "b": 2]],
                        ["id": "quoted", "value": ["value": ["ref": "literal-text"]]],
                        ["var": "count", "value": ["ref": "counted"]],
                        ["set": "count", "value": 2]
                    ],
                    "result": ["result": ["ref": "pair"]]
                ]
            ]
        ],
        // Branch, group and the condition spellings
        [
            "imports": ["std.logic.and", "std.logic.equal", "std.logic.not"],
            "procedures": [
                "entry": [
                    "parameters": ["word": "string", "ready": "bool"],
                    "body": [
                        ["var": "pick"],
                        [
                            "branch": [
                                // A connective is a word over sides nobody has
                                // asked yet, which is why each arrives as a
                                // closure. A notation may spell that; a document
                                // writes it.
                                "when": [
                                    "call": [
                                        "procedure": "std.logic.and",
                                        "of": [
                                            [
                                                "closure": [
                                                    "result": [
                                                        "call": [
                                                            "procedure": "std.logic.equal",
                                                            "of": ["ref": "word"],
                                                            "arguments": ["value": "hey"]
                                                        ]
                                                    ]
                                                ]
                                            ],
                                            [
                                                "closure": [
                                                    "result": [
                                                        "call": [
                                                            "procedure": "std.logic.not",
                                                            "of": ["ref": "ready"]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ],
                                "then": [["set": "pick", "value": "yes"]],
                                "else": [["set": "pick", "value": "no"]]
                            ]
                        ],
                        ["id": "grouped", "group": ["body": [["id": "inner", "value": 1]]]]
                    ],
                    "result": ["result": ["ref": "pick"]]
                ]
            ]
        ],
        // Loop, each, attempt
        [
            "imports": ["test.fail", "std.logic.notEqual", "std.math.plus"],
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "body": [
                        ["var": "seen", "value": 0],
                        [
                            "id": "walked",
                            "loop": [
                                "where": ["of": ["ref": "seen"], "notEqual": 3],
                                    "body": [
                                    [
                                        "set": "seen",
                                        "call": [
                                            "procedure": "std.math.plus",
                                            "of": ["ref": "seen"],
                                            "arguments": ["value": 1]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "id": "mapped",
                            "each": [
                                "in": ["ref": "names"],
                                "body": [["id": "one", "value": ["ref": "mapped.item"]]]
                            ]
                        ],
                        [
                            "id": "tried",
                            "attempt": [
                                "body": [["id": "risky", "fail": true]],
                                "result": ["ref": "risky"],
                                "rescue": ["result": "recovered"]
                            ]
                        ]
                    ],
                    "result": ["result": ["ref": "tried"]]
                ]
            ]
        ],
        // Leaving early, all three ways and both spellings of a target
        [
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "returns": "any",
                    "body": [
                        [
                            "id": "outer",
                            "loop": [
                                "where": false,
                                "body": [
                                    [
                                        "id": "walked",
                                        "each": [
                                            "in": ["ref": "names"],
                                            "body": [
                                                [
                                                    "branch": [
                                                        "when": true,
                                                        "then": [
                                                            [
                                                                "continue": Value.null
                                                            ]
                                                        ],
                                                        "else": [
                                                            ["break": "outer"]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        ["return": ["ref": "outer"]]
                    ]
                ]
            ]
        ],
        // Messages: receivers, carried bodies, closures, invocation, templates
        [
            "imports": ["std.collection.filter", "std.text.joined", "std.logic.notEqual", "std.text.text"],
            "procedures": [
                "entry": [
                    "parameters": ["word": "string", "names": "array<string>"],
                    "body": [
                        ["id": "shouted", "call": ["procedure": "shout", "of": ["ref": "word"]]],
                        [
                            "id": "kept",
                            "call": [
                                "procedure": "std.collection.filter",
                                "of": ["ref": "names"],
                                "arguments": [
                                    "by": [
                                        "closure": [
                                            "parameters": ["item": "string"],
                                            "returns": "bool",
                                            "result": [
                                                "call": [
                                                    "procedure": "std.logic.notEqual",
                                                    "of": ["ref": "item"],
                                                    "arguments": ["value": ""]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "id": "called",
                            "invoke": [
                                "procedure": [
                                    "closure": ["parameters": ["n": "int"], "result": ["ref": "n"]]
                                ],
                                "arguments": ["n": 1]
                            ]
                        ],
                        [
                            "id": "line",
                            "value": ["format": "${word}!", "with": ["word": ["ref": "word"]]]
                        ]
                    ],
                    "result": ["result": ["ref": "line"]]
                ],
                "shout": [
                    "receiver": "of",
                    "parameters": ["of": "string"],
                    "returns": "string",
                    "result": ["ref": "of"]
                ],
                "typed": [
                    "parameters": [
                        "how": ["type": ["pure procedure": ["parameters": ["it": "int"], "returns": "bool"]]],
                        "anything": ["type": "procedure"],
                        "parameter": "some Element"
                    ],
                    "returns": "never",
                    "result": ["ref": "anything"]
                ]
            ]
        ]
    ]
}

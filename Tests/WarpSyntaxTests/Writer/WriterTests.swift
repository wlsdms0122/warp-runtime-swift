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
import WarpStandard
import WarpTestSupport

// Writing is how a program leaves the machine that built it, so what it
// promises is not that the text comes back the same. It is that the program
// does. A document arrives spelled however its author liked it and is written
// back in the types the language actually has, which is why writing twice is
// the question these ask: the first pass says what the program is, and the
// second has to agree.
@Suite("A program can be written back out as a document")
struct WriterTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let sut = Writer()

    // Programs built rather than parsed. What they have in common is that no
    // reader made them, so nothing has already forced them into the types a
    // document happens to have, which is exactly where a writer goes wrong.
    private static let assembled: [Module] = [
        // Both cast spellings, over both ways a type is written. A name, and
        // one applied to another. A type written back as a string it cannot be
        // read from would survive neither direction.
        try! Module(
            types: ["App.Counted": .struct(["count": .int])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "payload", type: .any)]),
                    body: [
                        Statement(binding: .constant("named"), expression: .cast(
                                .reference([.name("payload")]),
                                as: .named("App.Counted"),
                                optional: false
                            )
                        ),
                        Statement(binding: .constant("asked"), expression: .cast(
                                .reference([.name("payload")]),
                                as: .array(.string),
                                optional: true
                            )
                        )
                    ],
                    result: .reference([.name("named"), .name("count")])
                )
            ]
        ),
        // Calls nested inside other expressions, deeper than a document's
        // fixed types would ever place them
        try! Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "procedure", type: .string)]),
                    body: [
                        Statement(binding: .constant("joined"), expression: .call(
                                Call(
                                    selector: "Standard.Text.joined",
                                    arguments: [
                                        .array([
                                            .call(
                                                Call(
                                                    selector: "Standard.Text.text",
                                                    arguments: [.reference([.name("procedure")])]
                                                )
                                            ),
                                            .literal(.string("!"))
                                        ]),
                                        .literal(.string(""))
                                    ]
                                )
                            )
                        ),
                        Statement(binding: .constant("held"), expression: .struct([
                                "line": .reference([.name("joined")]),
                                "size": .call(
                                    Call(selector: "Standard.Collection.count", arguments: [.reference([.name("procedure")])])
                                )
                            ])
                        )
                    ],
                    result: .reference([.name("held")])
                )
            ]
        ),
        // Data whose fields are named like tags, and a variable written twice
        try! Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("payload"), expression: .struct([
                                "ref": .literal(.string("not-a-path")),
                                "deep": .array([.struct(["value": .literal(.int(1))])])
                            ])
                        ),
                        Statement(binding: .variable("count"), expression: .literal(.int(0))),
                        Statement(binding: .assignment([.name("count")]), expression: .literal(.int(1)))
                    ],
                    result: .reference([.name("payload")])
                )
            ]
        )
    ]

    // The document format, written out. Every slot the language has appears
    // here exactly once, in the types that stand one to one with it. No
    // spelling stands in for anything.
    //
    // It is a fixture and also the closest thing to a statement of what a
    // document *is*. Something reading this from another language would need to
    // understand exactly what is written here and nothing else.
    private static let canonical: Value = [
        "warp": 1,
        "imports": ["Standard.Collection.count", "Standard.Comparable.lessThan", "Standard.Logic.notEqual", "Standard.Numeric.plus"],
        "description": "one of every type",
        "types": [
            "Task": [
                "struct": ["done": "Bool", "id": "String"],
                "satisfies": ["Scalar"],
                "procedures": ["label": ["parameters": [["name": "of", "type": "Task"]], "returns": "String", "result": ["ref": "of.id"]]]
            ]
        ],
        "contracts": ["Scalar": [:]],
        "extensions": [
            "Int": [
                "satisfies": ["Scalar"],
                "procedures": ["same": ["parameters": [["name": "of", "type": "Int"]], "returns": "Int", "result": ["ref": "of"]]]
            ],
            "String": ["satisfies": ["Scalar"]]
        ],
        "const": ["limit": 10],
        "procedures": [
            "entry": [
                "description": "every construct, once",
                "parameters": [
                    ["name": "kind", "type": "String"],
                    ["name": "names", "type": "Array<String>"],
                    ["name": "procedure", "type": "String", "description": "what to match"]
                ],
                "returns": "Dictionary<String, Any>",
                "body": [
                    ["let": "list", "value": [1, 2, 3]],
                    ["let": "pair", "value": ["struct": ["a": ["ref": "procedure"], "b": 2]]],
                    ["let": "tagged", "value": ["struct": ["ref": "not-a-path"]]],
                    ["var": "seen", "value": 0],
                    ["let": "indexed", "value": ["ref": "names[0]"]],
                    ["let": "computed", "value": ["ref": "names[seen].count"]],
                    [
                        "let": "walked",
                        "value": ["loop": [
                            "while": [
                                "call": [
                                    "procedure": "Standard.Logic.notEqual",
                                    "arguments": [["ref": "seen"], 3]
                                ]
                            ],
                            "body": [
                                [
                                    "set": "seen",
                                    "value": ["call": [
                                        "procedure": "Standard.Numeric.plus",
                                        "arguments": [["ref": "seen"], 1]
                                    ]
                                ]]
                            ]
                        ]
                    ]],
                    ["var": "pick"],
                    [
                        "value": ["conditional": [
                            "when": ["ref": "kind"],
                            "then": [["set": "pick", "value": "yes"]],
                            "else": [["set": "pick", "value": "no"]]
                        ]
                    ]],
                    [
                        "let": "mapped",
                        "value": ["loop": [
                            "while": [
                                "call": [
                                    "procedure": "Standard.Comparable.lessThan",
                                    "arguments": [
                                        ["ref": "mapped.index"],
                                        ["call": [
                                            "procedure": "Standard.Collection.count",
                                            "arguments": [["ref": "names"]]
                                        ]]
                                    ]
                                ]
                            ],
                            "body": [["let": "one", "value": ["ref": "names[mapped.index]"]]]
                        ]
                    ]],
                    [
                        "let": "tried",
                        "value": ["attempt": [
                            "body": [["let": "risky", "value": 1]],
                            "result": ["ref": "risky"],
                            "rescue": [
                                "body": [["let": "instead", "value": 0]],
                                "result": ["ref": "instead"]
                            ]
                        ]
                    ]],
                    [
                        "let": "called",
                        "value": ["call": [
                            "procedure": [
                                "closure": ["parameters": [["name": "n", "type": "Int"]], "result": ["ref": "n"]]
                            ],
                            "arguments": [1]
                        ]
                    ]]
                ],
                "result": ["dictionary": [["result", ["ref": "pick"]]]]
            ],
            "typed": [
                "parameters": [
                    ["name": "anything", "type": "Procedure"],
                    ["name": "bounded", "type": "some T: Scalar"],
                    ["name": "how", "type": ["const procedure": ["parameters": ["Int"], "returns": "Bool"]]],
                    ["name": "of", "type": "String"],
                    ["name": "parameter", "type": "some Element"],
                    ["name": "shaped", "type": "Task"]
                ],
                "returns": "Never",
                "result": ["ref": "of"]
            ]
        ]
    ]

    // One document per construct the language has, written the way a document
    // usually is. Spellings and all, since what comes out the far side is the
    // thing under test.
    static let corpus: [Value] = [
        // Literals, references, structs, arrays and a field named like a tag
        [
            "description": "the types that need no name",
            "types": ["Task": ["struct": ["id": "String", "done": "Bool"]]],
            "const": ["limit": 10],
            "procedures": [
                "entry": [
                    "parameters": [
                        ["name": "counted", "type": "Int", "description": "how many"],
                        ["name": "kind", "type": "String"],
                        ["name": "procedure", "type": "String"]
                    ],
                    "returns": "Dictionary<String, Any>",
                    "body": [
                        ["let": "list", "value": [1, 2, 3]],
                        ["let": "pair", "value": ["struct": ["a": ["ref": "procedure"], "b": 2]]],
                        ["let": "tagged", "value": ["struct": ["ref": "literal-text"]]],
                        ["var": "count", "value": ["ref": "counted"]],
                        ["set": "count", "value": 2]
                    ],
                    "result": ["dictionary": [["result", ["ref": "pair"]]]]
                ]
            ]
        ],
        // Branch, block and the condition spellings
        [
            "imports": ["Standard.Logic.and", "Standard.Logic.equal", "Standard.Logic.not"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "procedure", "type": "String"], ["name": "ready", "type": "Bool"]],
                    "body": [
                        ["var": "pick"],
                        [
                            "value": ["conditional": [
                                // A connective is a procedure over sides nobody has
                                // asked yet, which is why each arrives as a
                                // closure. A notation may spell that; a document
                                // writes it.
                                "when": [
                                    "call": [
                                        "procedure": "Standard.Logic.and",
                                        "arguments": [
                                            [
                                                [
                                                    "closure": [
                                                        "result": [
                                                            "call": [
                                                                "procedure": "Standard.Logic.equal",
                                                                "arguments": [["ref": "procedure"], "hey"]
                                                            ]
                                                        ]
                                                    ]
                                                ],
                                                [
                                                    "closure": [
                                                        "result": [
                                                            "call": [
                                                                "procedure": "Standard.Logic.not",
                                                                "arguments": [["ref": "ready"]]
                                                            ]
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
                        ]]
                    ],
                    "result": ["dictionary": [["result", ["ref": "pick"]]]]
                ]
            ]
        ],
        // Loop, attempt
        [
            "imports": ["Test.fail", "Standard.Collection.count", "Standard.Logic.notEqual", "Standard.Comparable.lessThan", "Standard.Numeric.plus"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "names", "type": "Array<String>"]],
                    "body": [
                        ["var": "seen", "value": 0],
                        [
                            "let": "walked",
                            "value": ["loop": [
                                "while": ["of": ["ref": "seen"], "notEqual": 3],
                                    "body": [
                                    [
                                        "set": "seen",
                                        "value": ["call": [
                                            "procedure": "Standard.Numeric.plus",
                                            "arguments": [["ref": "seen"], 1]
                                        ]
                                    ]]
                                ]
                            ]
                        ]],
                        [
                            "let": "mapped",
                            "value": ["loop": [
                                "while": [
                                    "of": ["ref": "mapped.index"],
                                    "lessThan": ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]
                                ],
                                "body": [["let": "one", "value": ["ref": "names[mapped.index]"]]]
                            ]
                        ]],
                        [
                            "let": "tried",
                            "value": ["attempt": [
                                "body": [["let": "risky", "value": ["fail": true]]],
                                "result": ["ref": "risky"],
                                "rescue": ["result": "recovered"]
                            ]
                        ]]
                    ],
                    "result": ["dictionary": [["result", ["ref": "tried"]]]]
                ]
            ]
        ],
        // Leaving early, all three ways and both spellings of a target
        [
            "imports": ["Standard.Collection.count", "Standard.Comparable.lessThan"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "names", "type": "Array<String>"]],
                    "returns": "Any",
                    "body": [
                        [
                            "let": "outer",
                            "value": ["loop": [
                                "while": false,
                                "body": [
                                    [
                                        "let": "walked",
                                        "value": ["loop": [
                                            "while": [
                                                "of": ["ref": "walked.index"],
                                                "lessThan": ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]
                                            ],
                                            "body": [
                                                [
                                                    "value": ["conditional": [
                                                        "when": true,
                                                        "then": [
                                                            [
                                                                "value": ["continue": Value.null
                                                            ]]
                                                        ],
                                                        "else": [
                                                            ["value": ["break": "outer"]]
                                                        ]
                                                    ]
                                                ]]
                                            ]
                                        ]
                                    ]]
                                ]
                            ]
                        ]]
                    ],
                    "result": "done"
                ]
            ]
        ],
        // Calls: by position, carried bodies, closures, invocation, templates
        [
            "imports": ["Standard.Collection.filter", "Standard.Text.joined", "Standard.Logic.notEqual", "Standard.Text.text"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "names", "type": "Array<String>"], ["name": "procedure", "type": "String"]],
                    "body": [
                        ["let": "shouted", "value": ["call": ["procedure": "shout", "arguments": [["ref": "procedure"]]]]],
                        [
                            "let": "kept",
                            "value": ["call": [
                                "procedure": "Standard.Collection.filter",
                                "arguments": [
                                    ["ref": "names"],
                                    [
                                        "closure": [
                                            "parameters": [["name": "item", "type": "String"]],
                                            "returns": "Bool",
                                            "result": [
                                                "call": [
                                                    "procedure": "Standard.Logic.notEqual",
                                                    "arguments": [["ref": "item"], ""]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ]],
                        [
                            "let": "called",
                            "value": ["call": [
                                "procedure": [
                                    "closure": ["parameters": [["name": "n", "type": "Int"]], "result": ["ref": "n"]]
                                ],
                                "arguments": [1]
                            ]
                        ]],
                        [
                            "let": "line",
                            "value": ["format": "${procedure}!", "with": ["procedure": ["ref": "procedure"]]]
                        ]
                    ],
                    "result": ["dictionary": [["result", ["ref": "line"]]]]
                ],
                "shout": [
                    "parameters": [["name": "of", "type": "String"]],
                    "returns": "String",
                    "result": ["ref": "of"]
                ],
                "typed": [
                    "parameters": [
                        ["name": "anything", "type": "Procedure"],
                        ["name": "how", "type": ["const procedure": ["parameters": ["Int"], "returns": "Bool"]]],
                        ["name": "parameter", "type": "some Element"]
                    ],
                    "returns": "Never",
                    "result": ["ref": "anything"]
                ]
            ]
        ]
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a draft's contract procedure holding a bound is written with it, and the reading refuses it")
    func aBoundedContractProcedureIsWrittenAsItIs() throws {
        // Given. A draft is held to no rule, so the bound reaches the writer
        let draft = Draft(
            contracts: [
                "App.Kept": [
                    "keep": ContractProcedure(
                        signature: Signature(
                            parameters: [Parameter(name: "of", type: .selfType), Parameter(name: "with", type: .parameter(name: "T"))],
                            bounds: ["T": ["App.Kept"]]
                        )
                    )
                ]
            ]
        )

        // When
        let written = try Writer().value(of: draft)

        // Then. The bound is written rather than dropped, and the load
        // refuses it where it stands
        let refused = #expect(throws: ValidationError.self) {
            try Loader().load(written, identity: nil)
        }

        #expect(refused?.place?.rendered == "contracts.App.Kept.procedures.keep.parameters[1]")
    }

    @Test("a draft bounding a name its list does not hold has no document to write", arguments: [
        Draft(types: ["App.Box": .struct(["item": .parameter(name: "T")], typeParameters: ["T"], bounds: ["U": ["Hashable"]])]),
        Draft(contracts: ["App.Keyed": Contract(types: ["Item"], bounds: ["Key": ["Hashable"]])])
    ])
    func aBoundOutsideItsListIsNotWritten(draft: Draft) {
        // When / Then. A bound stands beside the name it bounds, and one with
        // no name to stand beside would be dropped
        #expect(throws: WritingError.self) {
            try Writer().value(of: draft)
        }
    }

    @Test("a call of literal text has no document to write")
    func aCallOfTextIsNotWritten() throws {
        // Given. Text under `procedure` reads back as a declaration's name, so
        // a value that is text cannot be written there
        let sut = try Module(
            procedures: [
                "entry": Procedure(body: [], result: .apply(.literal(.string("App.f")), arguments: []))
            ]
        )

        // When / Then
        #expect(throws: WritingError.self) {
            try Writer().value(of: sut)
        }
    }

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
        // Given. Every other corpus here starts from a document, so what they
        // check is that documents survive. The half this direction exists for
        // is the other one: a program built by hand, which no reader has ever
        // seen and no notation has had a chance to normalise.
        let once = try sut.value(of: module)

        // When
        let twice = try sut.value(of: try loader.load(once))

        // Then
        #expect(once == twice)
    }

    @Test("a named struct is data wherever it stands, written plainly and read back so")
    func aNamedStructIsWrittenPlainly() throws {
        // Given. A field named for a tag, under a name that makes the struct
        // data
        let point = try Value.holding([(name: Name("ref"), value: Value.int(1))], named: "Point")

        // When / Then. The writer leaves it as it is and the reader reads it as
        // itself
        #expect(try Writer().value(of: Expression.literal(point)) == point)
        guard case let .literal(read) = try Loader().expression(from: point), read == point else {
            Issue.record("the named struct was not read as itself")

            return
        }
    }

    @Test("a canonical document is written back exactly as it was")
    func aCanonicalDocumentIsWrittenBackUnchanged() throws {
        // Given / When. `canonical` is written in the types themselves, so
        // reading it and writing it must arrive at the same document. A fixed
        // point only says the writing stopped changing; this says nothing was left
        // behind, because every slot the language has is written down here and
        // a slot that stopped being written would go missing from the answer.
        let sut = try sut.value(of: try loader.load(Self.canonical))

        // Then
        #expect(sut == Self.canonical)
    }

    @Test("nothing written is spelled", arguments: Self.corpus)
    func nothingWrittenIsSpelled(_ document: Value) throws {
        // Given. The two template keys, which are reserved in every notation.
        // The condition spelling these are read with is recognised by `of`,
        // which is the key a cast writes what it reads under, so it leaves no
        // key here that a survival could be told apart by. A spelling whose key
        // is not also a procedure is asked about below.
        let spellings: Set<Name> = ["format", "with"]

        // When. The corpus is written with every spelling the notation has.
        let written = try sut.value(of: try loader.loadDocument(document))

        // Then. What comes back may use none of them, because a spelling is a
        // rule the reading side would have to implement the same way, and the
        // reading side is somewhere else.
        #expect(try Self.keys(in: written).isDisjoint(with: spellings))
    }

    @Test("a spelling whose key is nobody's procedure does not survive being written")
    func aSpelledKeyIsNotWrittenBack() throws {
        // Given. The corpus above cannot answer this. Its notation names the
        // procedure in the document (`{ of: x, equal: y }`), so a key that survived
        // and a procedure that was written look the same on the way out. This one
        // spells `holds` and reaches `Example.holds`, and the key appears in a
        // document only if the writing side kept a spelling.
        let loader = Loader()
        let module = try loader.loadProcedure([
            "parameters": [["name": "ready", "type": "Bool"]],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["holds": ["ref": "ready"]],
                        "then": [["let": "kept", "value": "yes"]]
                    ]
                ]]
            ]
        ], importing: ["Example.holds"], from: Notation(spelling: OwnVocabularySpelling()))

        // When
        let written = try sut.value(of: module)

        // Then
        #expect(try !Self.keys(in: written).contains("holds"))
        #expect(try Self.keys(in: written).contains("call"))
    }

    @Test("a written program runs the way the one it came from did")
    func aWrittenProgramRunsTheSame() async throws {
        // Given. A fixed point says the writing stopped changing, not that it kept
        // everything. Running both is what notices a slot dropped on the way
        // out.
        let document: Value = [
            "imports": [
                "Standard.Collection.count",
                "Standard.Comparable.lessThan",
                "Standard.Logic.equal",
                "Standard.Numeric.plus",
                "Standard.Text.joined",
                "Standard.Text.text"
            ],
            "procedures": [
                "entry": [
                    "parameters": [["name": "names", "type": "Array<String>"], ["name": "procedure", "type": "String"]],
                    "body": [
                        ["var": "pick"],
                        [
                            "value": ["conditional": [
                                "when": ["of": ["ref": "procedure"], "equal": "hey"],
                                "then": [["set": "pick", "value": "matched"]],
                                "else": [["set": "pick", "value": "missed"]]
                            ]
                        ]],
                        ["var": "walked", "value": 0],
                        [
                            "let": "sized",
                            "value": ["loop": [
                                "while": [
                                    "of": ["ref": "sized.index"],
                                    "lessThan": ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]
                                ],
                                "body": [
                                    [
                                        "set": "walked",
                                        "value": ["call": [
                                            "procedure": "Standard.Numeric.plus",
                                            "arguments": [
                                                ["ref": "walked"],
                                                ["call": [
                                                    "procedure": "Standard.Collection.count",
                                                    "arguments": [["ref": "names[sized.index]"]]
                                                ]]
                                            ]
                                        ]
                                    ]]
                                ]
                            ]
                        ]],
                        [
                            "let": "line",
                            "value": [
                                "format": "${procedure}/${pick}",
                                "with": ["procedure": ["ref": "procedure"], "pick": ["ref": "pick"]]
                            ]
                        ]
                    ],
                    "result": ["dictionary": [["picked", ["ref": "pick"]], ["sizes", ["ref": "walked"]], ["line", ["ref": "line"]]]]
                ]
            ]
        ]
        let arguments: [Name: Value] = [
            "names": .array([.string("a"), .string("bb")]),
            "procedure": .string("hey")
        ]

        let original = try loader.loadDocument(document)
        let travelled = try loader.load(try sut.value(of: original))

        // When
        let before = try await run(original, arguments: arguments)
        let after = try await run(travelled, arguments: arguments)

        // Then
        #expect(before == after)
        #expect(before.map?["picked"] == .string("matched"))
        #expect(before.map?["sizes"] == .int(3))
        #expect(before.map?["line"] == .string("hey/matched"))
    }

    @Test("a spelling is written back as the call it stood for")
    func aSpellingIsWrittenPlainly() throws {
        // Given. `{ of: x, equal: y }` is a spelling, and what it means is a
        // call. Writing keeps the meaning and drops the spelling, which is
        // the whole reason the layers are worth separating.
        let module = try loader.loadProcedure([
            "parameters": [["name": "procedure", "type": "String"]],
            "body": [
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "procedure"], "equal": "hey"],
                        "then": [["let": "kept", "value": "matched"]]
                    ]
                ]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let written = try sut.value(of: module)

        // Then
        guard
            case let .array(body)? = written.map?["procedures"]?.map?["entry"]?.map?["body"],
            let call = body.first?.map?["value"]?.map?["conditional"]?.map?["when"]?.map?["call"]
        else {
            Issue.record("a conditional is written with a condition under `when`")

            return
        }

        // The procedure the spelling reached, written as the call it always was.
        #expect(call.map?["procedure"] == .string("Standard.Logic.equal"))
        #expect(call.map?["of"] == nil)
        #expect(call.map?["arguments"] == .array([.dictionary(["ref": .string("procedure")]), .string("hey")]))
    }

    @Test("a struct whose field is named like a tag is written under `struct` and read back as a struct")
    func aFieldNamedLikeATagIsWrittenUnderStruct() throws {
        // Given. A payload with a field called `ref` is not a reference, and a
        // struct of expressions with one is not either
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("payload"), expression: .struct(["ref": .literal(.string("not-a-path"))])
                        ),
                        Statement(binding: .constant("held"), expression: .struct(["ref": .reference([.name("payload")])])
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
            case let .array(body)? = written.map?["procedures"]?.map?["entry"]?.map?["body"],
            case let .body(block) = read.procedures["entry"]?.implementation,
            block.body.statements.count == 2,
            case let .struct(payload) = block.body.statements[0].expression,
            case let .struct(held) = block.body.statements[1].expression
        else {
            Issue.record("a struct written under `struct` reads back as a struct")

            return
        }

        #expect(body.first?.map?["value"] == .dictionary(["struct": .dictionary(["ref": "not-a-path"])]))
        #expect(body.last?.map?["value"] == .dictionary(["struct": .dictionary(["ref": .dictionary(["ref": "payload"])])]))
        #expect(payload["ref"]?.constantValue == .string("not-a-path"))
        #expect(held["ref"]?.referencePath == [.name("payload")])
    }

    @Test("a notation that gave up a construct key cannot write what it said")
    func aDroppedKeyCannotBeWritten() throws {
        // Given. The registry is what a notation *is*, so a construct whose key
        // it no longer registers is one it can no longer write. Answering with
        // the built-in spelling would put a key in the document that reading it
        // back through this same notation would refuse.
        let module = try loader.loadProcedure([
            "body": [
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": false,
                        "body": [["let": "step", "value": 1]]
                    ]
                ]]
            ]
        ])
        let narrowed = Writer(registry: ConstructRegistry.standard.removing(LoopForm.key))

        // When / Then
        #expect(throws: WritingError.self) {
            try narrowed.value(of: module)
        }

        // And the same program through a notation that kept the key is fine
        #expect(throws: Never.self) {
            try sut.value(of: module)
        }
    }

    @Test("a bound is written once, beside the first naming the declaring signature's slots write")
    func aBoundIsWrittenInTheDeclaringSignature() throws {
        // Given. A slot names the parameter, and the signature holds the bound
        let bounded = Signature(
            parameters: [
                Parameter(name: "item", type: .parameter(name: "T"))
            ],
            returns: .bool,
            bounds: ["T": ["Scalar"]]
        )
        let declaring = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: bounded,
                    body: [],
                    result: .literal(.bool(true))
                )
            ]
        )

        // When
        let written = try sut.value(of: declaring)

        // Then
        guard
            case let .dictionary(document) = written,
            case let .dictionary(procedures) = document["procedures"],
            case let .dictionary(entry) = procedures[entryName]
        else {
            Issue.record("the module did not write as a document")

            return
        }

        #expect(entry["bounds"] == nil)

        guard
            case let .array(parameters) = entry["parameters"]
        else {
            Issue.record("the parameters did not write as a list")

            return
        }

        #expect(parameters == [.dictionary(["name": .string("item"), "type": .string("some T: Scalar")])])
    }

    @Test("a procedure backed by native code has no document")
    func nativeCodeHasNoDocument() throws {
        // Given. What the host brings is declared in a module it assembles into
        // the link, not carried in the program. Writing its name alone would
        // make a document that loads into a body nobody wrote.
        let module = try Module(
            procedures: Module.logic.reduce(into: [Name: Procedure]()) { held, bundle in
                held.merge(bundle.procedures) { first, _ in first }
            }
        )

        // When / Then
        #expect(throws: WritingError.self) {
            try sut.value(of: module)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Every key anywhere in a document. A spelling is a procedure, and a procedure could
    // be written at any depth, so asking whether one survived is asking about
    // the whole of it.
    private static func keys(in value: Value) throws -> Set<Name> {
        switch value {
        case let .array(elements):
            return try elements.reduce(into: Set<Name>()) { found, element in
                found.formUnion(try keys(in: element))
            }

        case let .dictionary(mapping):
            let named = try mapping.named()

            return try named.reduce(into: Set(named.map(\.name))) { found, entry in
                found.formUnion(try keys(in: entry.value))
            }

        default:
            return []
        }
    }
}

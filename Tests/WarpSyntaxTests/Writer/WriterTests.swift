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

// The writer gives the one way a document says the program the load read,
// and the load holds every document to it. So what these ask is that the
// one way reads back as the program it was written from, and that writing
// it again gives the same text.
@Suite("A program the load read is written back in its one way")
struct WriterTests {
    // MARK: - Property
    private let loader = Loader()
    private let sut = Writer()

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
        "types": [
            "Task": [
                "struct": ["done": "Bool", "id": "String"],
                "satisfies": ["Scalar"],
                "procedures": ["label": ["parameters": [["name": "of", "type": "Task"]], "returns": "String", "body": [["value": ["return": ["ref": "of.id"]]]]]]
            ]
        ],
        "contracts": ["Scalar": [:]],
        "extensions": [
            "Int": [
                "satisfies": ["Scalar"],
                "procedures": ["same": ["parameters": [["name": "of", "type": "Int"]], "returns": "Int", "body": [["value": ["return": ["ref": "of"]]]]]]
            ],
            "String": ["satisfies": ["Scalar"]]
        ],
        "const": ["limit": 10],
        "procedures": [
            "entry": [
                "parameters": [
                    ["name": "kind", "type": "String"],
                    ["name": "names", "type": "Array<String>"],
                    ["name": "procedure", "type": "String"]
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
                        "value": ["try": [
                            "body": [["let": "risky", "value": 1]],
                            "catch": [["let": "instead", "value": 0]]
                        ]
                    ]],
                    [
                        "let": "called",
                        "value": ["call": [
                            "procedure": [
                                "closure": ["parameters": [["name": "n", "type": "Int"]], "body": [["value": ["return": ["ref": "n"]]]]]
                            ],
                            "arguments": [1]
                        ]
                    ]],
                    ["value": ["return": ["dictionary": [["result", ["ref": "pick"]]]]]]
                ]
            ],
            "typed": [
                "parameters": [
                    ["name": "anything", "type": "Procedure"],
                    ["name": "bounded", "type": "some T: Scalar"],
                    ["name": "how", "type": "const (Int) -> Bool"],
                    ["name": "of", "type": "String"],
                    ["name": "parameter", "type": "some Element"],
                    ["name": "shaped", "type": "Task"]
                ],
                "returns": "Never",
                "body": [["value": ["return": ["ref": "of"]]]]
            ]
        ]
    ]

    // One document per construct the language has, written the way a document
    // usually is. Spellings and all, since what comes out the far side is the
    // thing under test.
    static let corpus: [Value] = [
        // Literals, references, structs, arrays and a field named like a tag
        [
            "types": ["Task": ["struct": ["id": "String", "done": "Bool"]]],
            "const": ["limit": 10],
            "procedures": [
                "entry": [
                    "parameters": [
                        ["name": "counted", "type": "Int"],
                        ["name": "kind", "type": "String"],
                        ["name": "procedure", "type": "String"]
                    ],
                    "returns": "Dictionary<String, Any>",
                    "body": [
                        ["let": "list", "value": [1, 2, 3]],
                        ["let": "pair", "value": ["struct": ["a": ["ref": "procedure"], "b": 2]]],
                        ["let": "tagged", "value": ["struct": ["ref": "literal-text"]]],
                        ["var": "count", "value": ["ref": "counted"]],
                        ["set": "count", "value": 2],
                        ["value": ["return": ["dictionary": [["result", ["ref": "pair"]]]]]]
                    ]
                ]
            ]
        ],
        // Branch and the condition spellings
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
                                // closure.
                                "when": [
                                    "call": [
                                        "procedure": "Standard.Logic.and",
                                        "arguments": [
                                            [
                                                [
                                                    "closure": [
                                                        "body": [["value": ["return": [
                                                            "call": [
                                                                "procedure": "Standard.Logic.equal",
                                                                "arguments": [["ref": "procedure"], "hey"]
                                                            ]
                                                        ]]]]
                                                    ]
                                                ],
                                                [
                                                    "closure": [
                                                        "body": [["value": ["return": [
                                                            "call": [
                                                                "procedure": "Standard.Logic.not",
                                                                "arguments": [["ref": "ready"]]
                                                            ]
                                                        ]]]]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ],
                                "then": [["set": "pick", "value": "yes"]],
                                "else": [["set": "pick", "value": "no"]]
                            ]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "pick"]]]]]]
                    ]
                ]
            ]
        ],
        // Loop, try
        [
            "imports": ["Standard.Collection.count", "Standard.Comparable.lessThan", "Standard.Logic.notEqual", "Standard.Numeric.plus", "Test.fail"],
            "procedures": [
                "entry": [
                    "parameters": [["name": "names", "type": "Array<String>"]],
                    "body": [
                        ["var": "seen", "value": 0],
                        [
                            "let": "walked",
                            "value": ["loop": [
                                "while": ["call": ["procedure": "Standard.Logic.notEqual", "arguments": [["ref": "seen"], 3]]],
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
                                "while": ["call": ["procedure": "Standard.Comparable.lessThan", "arguments": [["ref": "mapped.index"], ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]]]],
                                "body": [["let": "one", "value": ["ref": "names[mapped.index]"]]]
                            ]
                        ]],
                        ["var": "tried"],
                        [
                            "value": ["try": [
                                "body": [["let": "risky", "value": ["call": ["procedure": "Test.fail", "arguments": [true]]]], ["set": "tried", "value": ["ref": "risky"]]],
                                "catch": [["set": "tried", "value": "recovered"]]
                            ]
                        ]],
                        ["value": ["return": ["dictionary": [["result", ["ref": "tried"]]]]]]
                    ]
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
                                            "while": ["call": ["procedure": "Standard.Comparable.lessThan", "arguments": [["ref": "walked.index"], ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]]]],
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
                        ]],
                        ["value": ["return": "done"]]
                    ]
                ]
            ]
        ],
        // Calls: by position, carried bodies, closures, invocation, text joined from pieces
        [
            "imports": ["Standard.Collection.filter", "Standard.Logic.notEqual", "Standard.Text.joined", "Standard.Text.text"],
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
                                            "body": [["value": ["return": [
                                                "call": [
                                                    "procedure": "Standard.Logic.notEqual",
                                                    "arguments": [["ref": "item"], ""]
                                                ]
                                            ]]]]
                                        ]
                                    ]
                                ]
                            ]
                        ]],
                        [
                            "let": "called",
                            "value": ["call": [
                                "procedure": [
                                    "closure": ["parameters": [["name": "n", "type": "Int"]], "body": [["value": ["return": ["ref": "n"]]]]]
                                ],
                                "arguments": [1]
                            ]
                        ]],
                        [
                            "let": "line",
                            "value": ["call": ["procedure": "Standard.Text.joined", "arguments": [[["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "procedure"]]]], "!"], ""]]]
                        ],
                        ["value": ["return": ["dictionary": [["result", ["ref": "line"]]]]]]
                    ]
                ],
                "shout": [
                    "parameters": [["name": "of", "type": "String"]],
                    "returns": "String",
                    "body": [["value": ["return": ["ref": "of"]]]]
                ],
                "typed": [
                    "parameters": [
                        ["name": "anything", "type": "Procedure"],
                        ["name": "how", "type": "const (Int) -> Bool"],
                        ["name": "parameter", "type": "some Element"]
                    ],
                    "returns": "Never",
                    "body": [["value": ["return": ["ref": "anything"]]]]
                ]
            ]
        ]
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a call of a literal string has no document to write")
    func aCallOfAStringIsNotWritten() throws {
        // Given. A string under `procedure` reads back as a declaration's name,
        // so a value that is a string cannot be written there
        let sut = try Module(
            procedures: [
                "entry": Procedure(body: [returning(.apply(.literal(.string("App.f")), arguments: []))])
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

    @Test("a named struct is data wherever it stands, written plainly and read back so")
    func aNamedStructIsWrittenPlainly() throws {
        // Given. A field named for a tag, under a name that makes the struct
        // data
        let point = try Value.holding([(name: Name("ref"), value: Value.int(1))], named: "Point")

        // When / Then. The writer leaves it as it is and the reader reads it as
        // itself
        #expect(try Writer().value(of: Expression.literal(point)) == point)
        guard case let .literal(literal) = try read(ExpressionReader.self, from: point).expression, literal == point else {
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
        // a slot that stopped being written would go missing from the result.
        let sut = try sut.value(of: try loader.load(Self.canonical))

        // Then
        #expect(sut == Self.canonical)
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
                    "returns": "Any",
                    "parameters": [["name": "names", "type": "Array<String>"], ["name": "procedure", "type": "String"]],
                    "body": [
                        ["var": "pick"],
                        [
                            "value": ["conditional": [
                                "when": ["call": ["procedure": "Standard.Logic.equal", "arguments": [["ref": "procedure"], "hey"]]],
                                "then": [["set": "pick", "value": "matched"]],
                                "else": [["set": "pick", "value": "missed"]]
                            ]
                        ]],
                        ["var": "walked", "value": 0],
                        [
                            "let": "sized",
                            "value": ["loop": [
                                "while": ["call": ["procedure": "Standard.Comparable.lessThan", "arguments": [["ref": "sized.index"], ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]]]],
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
                            "value": ["call": ["procedure": "Standard.Text.joined", "arguments": [[["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "procedure"]]]], "/", ["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "pick"]]]]], ""]]]
                        ],
                        ["value": ["return": ["dictionary": [["picked", ["ref": "pick"]], ["sizes", ["ref": "walked"]], ["line", ["ref": "line"]]]]]]
                    ]
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
        #expect(before.dictionaryValue?["picked"] == .string("matched"))
        #expect(before.dictionaryValue?["sizes"] == .int(3))
        #expect(before.dictionaryValue?["line"] == .string("hey/matched"))
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
                        "when": ["call": ["procedure": "Standard.Logic.equal", "arguments": [["ref": "procedure"], "hey"]]],
                        "then": [["let": "kept", "value": "matched"]]
                    ]
                ]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let written = try sut.value(of: module)

        // Then
        guard
            case let .array(body)? = written.dictionaryValue?["procedures"]?.dictionaryValue?["entry"]?.dictionaryValue?["body"],
            let call = body.first?.dictionaryValue?["value"]?.dictionaryValue?["conditional"]?.dictionaryValue?["when"]?.dictionaryValue?["call"]
        else {
            Issue.record("a conditional is written with a condition under `when`")

            return
        }

        // The procedure the spelling reached, written as the call it always was.
        #expect(call.dictionaryValue?["procedure"] == .string("Standard.Logic.equal"))
        #expect(call.dictionaryValue?["of"] == nil)
        #expect(call.dictionaryValue?["arguments"] == .array([.dictionary(["ref": .string("procedure")]), .string("hey")]))
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
            case let .array(body)? = written.dictionaryValue?["procedures"]?.dictionaryValue?["entry"]?.dictionaryValue?["body"],
            case let .body(readBody) = read.procedures["entry"]?.implementation,
            readBody.statements.count == 2,
            case let .struct(payload) = readBody.statements[0].expression,
            case let .struct(held) = readBody.statements[1].expression
        else {
            Issue.record("a struct written under `struct` reads back as a struct")

            return
        }

        #expect(body.first?.dictionaryValue?["value"] == .dictionary(["struct": .dictionary(["ref": "not-a-path"])]))
        #expect(body.last?.dictionaryValue?["value"] == .dictionary(["struct": .dictionary(["ref": .dictionary(["ref": "payload"])])]))
        #expect(payload["ref"]?.constantValue == .string("not-a-path"))
        #expect(held["ref"]?.referencePath == [.name("payload")])
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
                    body: [returning(.literal(.bool(true)))]
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

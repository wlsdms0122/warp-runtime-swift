//
//  StandardTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// The words that ship in bundles, and the fact that they are bundles: a caller
// takes the ones its programs have use for, and a name from a bundle it left out
// does not resolve.
@Suite("The standard vocabulary")
struct StandardTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a bundle left out is a bundle whose names do not resolve")
    func aBundleLeftOutDoesNotResolve() throws {
        // Given — a program that only counts, linked without the bundle that
        // declares counting
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(
                                receiver: .literal(.array([.int(1)])),
                                selector: "count"
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut, .math, .text, .foundation], entry: entryName)
        }

        #expect(throws: Never.self) {
            try linker.link([sut, .collection, .foundation], entry: entryName)
        }
    }

    @Test("a connective leaves the rest unasked once the answer is settled")
    func connectivesShortCircuit() async throws {
        // Given — the later side divides by zero, which refuses when it is
        // asked. `all` is settled by the first false, so it never is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "verdict",
                            expression: every(
                                equals(.literal(.int(1)), .literal(.int(2))),
                                equals(
                                    .dispatch(Dispatch(
                                        receiver: .literal(.int(1)),
                                        selector: "dividedBy",
                                        arguments: ["value": .literal(.int(0))]
                                    )),
                                    .literal(.int(0))
                                )
                            )
                        )
                    ],
                    result: reference("verdict")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .bool(false))
    }

    @Test("a word takes a procedure the author wrote and runs it")
    func aWalkTakesAProcedure() async throws {
        // Given — map, filter and reduce are declarations rather than
        // constructs. Nothing in the grammar knows they exist
        let doubling = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .int),
            body: [],
            result: .dispatch(Dispatch(
                receiver: reference("item"),
                selector: "times",
                arguments: ["value": .literal(.int(2))]
            ))
        )
        let odd = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .bool),
            body: [
                Statement(
                    id: "left",
                    expression: .dispatch(Dispatch(
                        receiver: reference("item"),
                        selector: "remainder",
                        arguments: ["value": .literal(.int(2))]
                    ))
                )
            ],
            result: equals(reference("left"), .literal(.int(1)))
        )
        let adding = Procedure(
            signature: Signature(
                parameters: [
                    "carried": Parameter(type: .int),
                    "item": Parameter(type: .int)
                ],
                returns: .int
            ),
            body: [],
            result: .dispatch(Dispatch(
                receiver: reference("carried"),
                selector: "plus",
                arguments: ["value": reference("item")]
            ))
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ns": Parameter(type: .array(.int))]),
                    body: [
                        Statement(
                            id: "doubled",
                            expression: .dispatch(Dispatch(
                                receiver: reference("ns"),
                                selector: "std.collection.map",
                                arguments: ["value": .closure(doubling)]
                            ))
                        ),
                        Statement(
                            id: "kept",
                            expression: .dispatch(Dispatch(
                                receiver: reference("ns"),
                                selector: "filter",
                                arguments: ["value": .closure(odd)]
                            ))
                        ),
                        Statement(
                            id: "total",
                            expression: .dispatch(Dispatch(
                                receiver: reference("ns"),
                                selector: "reduce",
                                arguments: [
                                    "from": .literal(.int(0)),
                                    "value": .closure(adding)
                                ]
                            ))
                        )
                    ],
                    result: .record([
                        "doubled": reference("doubled"),
                        "kept": reference("kept"),
                        "total": reference("total")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["ns": .array([.int(1), .int(2), .int(3)])]
        )

        // Then
        #expect(
            answer == .object([
                "doubled": .array([.int(2), .int(4), .int(6)]),
                "kept": .array([.int(1), .int(3)]),
                "total": .int(6)
            ])
        )
    }

    @Test("a walk declares what it hands over, and a body reads what it wants")
    func aWalkOffersRatherThanRequires() async throws {
        // Given — `reduce` hands over `carried` and `item`. Counting only needs
        // the first, and declaring the second to leave it unread would be a
        // declaration the author never meant
        let counting = Procedure(
            signature: Signature(
                parameters: ["carried": Parameter(type: .int)],
                returns: .int
            ),
            body: [],
            result: .dispatch(Dispatch(
                receiver: reference("carried"),
                selector: "plus",
                arguments: ["value": .literal(.int(1))]
            ))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ns": Parameter(type: .array(.int))]),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: reference("ns"),
                        selector: "reduce",
                        arguments: [
                            "from": .literal(.int(0)),
                            "value": .closure(counting)
                        ]
                    ))
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["ns": .array([.int(7), .int(8), .int(9)])]
        )

        // Then
        #expect(answer == .int(3))
    }

    @Test("a walk refuses a procedure that reaches outside")
    func aWalkRefusesAnImpureProcedure() throws {
        // Given — `map` declares `pure procedure`, so a body that shouts is
        // refused before any run rather than suspending inside a path
        let loud = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .string)]),
            body: [],
            result: .dispatch(Dispatch(
                selector: "shout",
                arguments: ["text": reference("item")]
            ))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["names": Parameter(type: .array(.string))]),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: reference("names"),
                        selector: "std.collection.map",
                        arguments: ["value": .closure(loud)]
                    ))
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut, .shouting] + Module.standard, entry: entryName)
        }
    }

    @Test("a divisor of zero refuses rather than taking the process")
    func divisionByZeroRefuses() async throws {
        // Given — both are Swift traps if the answer is taken rather than
        // judged, and each arrives at run time
        let asks: [(String, Value, Value)] = [
            ("remainder", .int(5), .int(0)),
            ("dividedBy", .int(5), .int(0))
        ]

        for (word, receiver, operand) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .dispatch(Dispatch(
                            receiver: .literal(receiver),
                            selector: word,
                            arguments: ["value": .literal(operand)]
                        ))
                    )
                ]
            )

            // When / Then
            await #expect(throws: ExecutionError.self, "\(word) took the process") {
                try await run(sut)
            }
        }
    }

    @Test("arithmetic off the word's edge is a fault, not a wrap")
    func wholeArithmeticOverflowFaults() async throws {
        // Given — each of these falls off the edge of the machine word, and
        // the language stops rather than answering a number the digits do not
        // say
        let asks: [(String, Value, Value)] = [
            ("times", .int(Int.max), .int(2)),
            ("plus", .int(Int.max), .int(1)),
            ("minus", .int(Int.min), .int(1))
        ]

        func asking(_ word: String, _ receiver: Value, _ operand: Value) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .dispatch(Dispatch(
                            receiver: .literal(receiver),
                            selector: word,
                            arguments: ["value": .literal(operand)]
                        ))
                    )
                ]
            )
        }

        for (word, receiver, operand) in asks {
            // When / Then
            await #expect(throws: ExecutionError.self, "\(word) answered") {
                try await run(asking(word, receiver, operand))
            }
        }

        // `Int.min remainder -1` trips the hardware's division, but the
        // remainder itself is 0 — an answer the word holds, so it answers.
        #expect(try await run(asking("remainder", .int(Int.min), .int(-1))) == .int(0))
    }

    @Test("a quotient is a fraction even between wholes")
    func aQuotientIsAFraction() async throws {
        // Given — dividedBy never answers an int; `floored` is where a whole
        // division's whole half is read back
        func divided(_ left: Int, _ right: Int) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .dispatch(Dispatch(
                            receiver: .literal(.int(left)),
                            selector: "dividedBy",
                            arguments: ["value": .literal(.int(right))]
                        ))
                    )
                ]
            )
        }

        // When / Then
        #expect(try await run(divided(6, 2)) == .double(3.0))
        #expect(try await run(divided(7, 2)) == .double(3.5))
        #expect(try await run(divided(Int.max, Int.max)) == .double(1.0))

        // The quotient is binary64's own: each whole operand widens first —
        // the same widening every mixed operation performs — and the division
        // rounds once more. 2^53 + 1 widens to 2^53, and the answer is the
        // widened pair's, bit for bit.
        #expect(
            try await run(divided(9_007_199_254_740_993, 3))
                == .double(9_007_199_254_740_992.0 / 3.0)
        )
    }

    @Test("a codec keeps its own contract on the encoding name")
    func aCodecReadsItsEncodingArgument() throws {
        // Given — the declaration's oneOf says the same names early; this is
        // the implementation refusing a name it has no mapping for, so a
        // drifted declaration cannot make it answer in the wrong encoding
        let sut = CodecQuery(.decoded)

        // When / Then
        #expect(
            try sut.evaluate(Question(
                receiver: .bytes([104]),
                arguments: ["encoding": .string("utf8")]
            )) == .string("h")
        )

        #expect {
            try sut.evaluate(Question(
                receiver: .bytes([104]),
                arguments: ["encoding": .string("utf16")]
            ))
        } throws: { error in
            "\(error)".contains("no encoding named 'utf16'")
        }
    }

    @Test("text spells a whole number the same way at every size and depth")
    func textSpellsWholeNumbersUniformly() async throws {
        // Given — the quotes must not change with the value's size: a number
        // is a number wherever it sits, and only text wears quotes
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.array([
                            .int(1),
                            .int(Int.max),
                            .string("9223372036854775807")
                        ])),
                        selector: "text"
                    ))
                )
            ]
        )

        // When / Then
        #expect(
            try await run(sut)
                == .string("[1,9223372036854775807,\"9223372036854775807\"]")
        )
    }

    @Test("rounding and magnitude stop at the word's edge")
    func roundingPastTheWordFaults() async throws {
        // Given — a fraction whose whole part is past the machine word has no
        // int to answer, and the word's own minimum has no magnitude the word
        // holds. The refusal names the overflow, not a missing whole answer —
        // the two reasons are different facts.
        let asks: [(String, Value)] = [
            ("floored", .double(1e30)),
            ("rounded", .double(1e30)),
            ("absolute", .int(Int.min))
        ]

        for (word, receiver) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .dispatch(Dispatch(
                            receiver: .literal(receiver),
                            selector: word
                        ))
                    )
                ]
            )

            // When / Then
            await #expect {
                try await run(sut)
            } throws: { error in
                "\(error)".contains("overflows int")
            }
        }
    }

    @Test("a whole division reads both halves")
    func wholeDivisionIsWritable() async throws {
        // Given — `dividedBy` always answers a double, so a whole division is
        // that floored, and what it left over is `remainder`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["n": Parameter(type: .int)]),
                    body: [
                        Statement(
                            id: "quotient",
                            expression: .dispatch(Dispatch(
                                receiver: reference("n"),
                                selector: "dividedBy",
                                arguments: ["value": .literal(.int(4))]
                            ))
                        ),
                        Statement(
                            id: "whole",
                            expression: .dispatch(Dispatch(
                                receiver: reference("quotient"),
                                selector: "floored"
                            ))
                        ),
                        Statement(
                            id: "left",
                            expression: .dispatch(Dispatch(
                                receiver: reference("n"),
                                selector: "remainder",
                                arguments: ["value": .literal(.int(4))]
                            ))
                        )
                    ],
                    result: .record([
                        "left": reference("left"),
                        "whole": reference("whole")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(sut, arguments: ["n": .int(11)])

        // Then
        #expect(answer == .object(["whole": .int(2), "left": .int(3)]))
    }

    @Test("an array grows and shrinks, which is a length the text did not write")
    func anArrayIsBuiltRatherThanSpelled() async throws {
        // Given — a body walking a grid: the head moves and wraps, the trail
        // takes it on and lets its own end go. Nothing here is a length the
        // author could have counted, and `each` cannot write it because `each`
        // answers one element for every element it was given.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: [
                            "trail": Parameter(type: .array(.int)),
                            "head": Parameter(type: .int),
                            "side": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "stepped",
                            expression: .dispatch(Dispatch(
                                receiver: reference("head"),
                                selector: "plus",
                                arguments: ["value": .literal(.int(1))]
                            ))
                        ),
                        Statement(
                            id: "wrapped",
                            expression: .dispatch(Dispatch(
                                receiver: reference("stepped"),
                                selector: "remainder",
                                arguments: ["value": reference("side")]
                            ))
                        ),
                        Statement(
                            id: "grown",
                            expression: .dispatch(Dispatch(
                                receiver: reference("trail"),
                                selector: "prepending",
                                arguments: ["value": reference("wrapped")]
                            ))
                        ),
                        Statement(
                            id: "moved",
                            expression: .dispatch(Dispatch(
                                receiver: reference("grown"),
                                selector: "dropLast"
                            ))
                        )
                    ],
                    result: .record([
                        "grown": reference("grown"),
                        "moved": reference("moved")
                    ])
                )
            ]
        )

        // When — the head sits at the last column, so stepping wraps it to 0
        let answer = try await run(
            sut,
            arguments: [
                "head": .int(3),
                "side": .int(4),
                "trail": .array([.int(3), .int(2), .int(1)])
            ]
        )

        // Then
        #expect(
            answer == .object([
                "grown": .array([.int(0), .int(3), .int(2), .int(1)]),
                "moved": .array([.int(0), .int(3), .int(2)])
            ])
        )
    }

    @Test("an object is walked and rebuilt without naming its fields")
    func anObjectIsDataRatherThanAShape() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["counts": Parameter(type: .object(.int))]),
                    body: [
                        Statement(
                            id: "named",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "keys"
                            ))
                        ),
                        Statement(
                            id: "held",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "values"
                            ))
                        ),
                        Statement(
                            id: "changed",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "setting",
                                arguments: [
                                    "key": .literal(.string("b")),
                                    "value": .literal(.int(9))
                                ]
                            ))
                        )
                    ],
                    result: .record([
                        "changed": reference("changed"),
                        "held": reference("held"),
                        "named": reference("named")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["counts": .object(["a": .int(1), "b": .int(2)])]
        )

        // Then
        #expect(
            answer == .object([
                "named": .array([.string("a"), .string("b")]),
                "held": .array([.int(1), .int(2)]),
                "changed": .object(["a": .int(1), "b": .int(9)])
            ])
        )
    }

    @Test("whole numbers stay whole, and a quotient does not")
    func arithmeticKeepsItsRepresentation() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "sum",
                            expression: .dispatch(Dispatch(selector: "plus", arguments: [
                                        "of": .literal(.int(2)),
                                        "value": .literal(.int(3))
                                    ]))
                        ),
                        Statement(
                            id: "product",
                            expression: .dispatch(Dispatch(selector: "times", arguments: [
                                        "of": .literal(.int(4)),
                                        "value": .literal(.double(2.5))
                                    ]))
                        ),
                        Statement(
                            id: "quotient",
                            expression: .dispatch(Dispatch(selector: "dividedBy", arguments: [
                                        "of": .literal(.int(7)),
                                        "value": .literal(.int(2))
                                    ]))
                        )
                    ],
                    result: .record([
                            "product": .reference([.key("product")]),
                            "quotient": .reference([.key("quotient")]),
                            "sum": .reference([.key("sum")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["sum"] == .int(5))
        #expect(outputs["product"] == .double(10))
        #expect(outputs["quotient"] == .double(3.5))
    }

    @Test("dividing by zero is refused rather than answered")
    func divisionByZeroFails() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "gone",
                            expression: .dispatch(Dispatch(selector: "dividedBy", arguments: [
                                        "of": .literal(.int(1)),
                                        "value": .literal(.int(0))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: ExecutionError.self) {
            try await run(sut)
        }
    }

    @Test("ordering reads as a condition, which is what it was missing")
    func comparisonReadsAsACondition() async throws {
        // Given — `{ of: x, lessThan: y }` is the condition grammar sending a
        // word, so ordering needed no grammar of its own
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "n": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "verdict",
                            binding: .variable,
                            expression: .literal(.string(""))
                        ),
                        Statement(
                            expression: .conditional(.dispatch(Dispatch(receiver: .reference([.key("n")]), selector: "lessThan", arguments: [
                                            "value": .literal(.int(10))
                                        ])), then: [
                                        Statement(
                                            id: "verdict",
                                            binding: .assignment,
                                            expression: .literal(.string("small"))
                                        )
                                    ], else: [
                                        Statement(
                                            id: "verdict",
                                            binding: .assignment,
                                            expression: .literal(.string("large"))
                                        )
                                    ])
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("verdict")])
                        ])
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["n": .int(3)])["result"] == .string("small"))
        #expect(try await run(sut, arguments: ["n": .int(30)])["result"] == .string("large"))
    }

    @Test("a word that needs nothing is reachable from a path")
    func nilaryWordsAreReachableFromPaths() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "items": Parameter(type: .array(.string)),
                            "name": Parameter(type: .string)
                        ]
                    ),
                    body: [],
                    result: .record([
                            "back": .reference([.key("items"), .key("reversed")]),
                            "head": .reference([.key("items"), .key("first")]),
                            "loud": .reference([.key("name"), .key("uppercased")]),
                            "tail": .reference([.key("items"), .key("last")]),
                            "together": .reference([.key("items"), .key("joined")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(
            sut,
            arguments: [
                "name": .string("warp"),
                "items": .array([.string("a"), .string("b")])
            ]
        )

        // Then
        #expect(outputs["loud"] == .string("WARP"))
        #expect(outputs["head"] == .string("a"))
        #expect(outputs["tail"] == .string("b"))
        #expect(outputs["back"] == .array([.string("b"), .string("a")]))
        #expect(outputs["together"] == .string("ab"))
    }

    @Test("text words compose the way a document writes them")
    func textWordsCompose() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "line": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "parts",
                            expression: .dispatch(Dispatch(selector: "split", arguments: [
                                        "of": .reference([.key("line")]),
                                        "value": .literal(.string(","))
                                    ]))
                        ),
                        Statement(
                            id: "rejoined",
                            expression: .dispatch(Dispatch(selector: "joined", arguments: [
                                        "of": .reference([.key("parts")]),
                                        "value": .literal(.string(" / "))
                                    ]))
                        ),
                        Statement(
                            id: "fixed",
                            expression: .dispatch(Dispatch(selector: "replacing", arguments: [
                                        "of": .reference([.key("rejoined")]),
                                        "value": .literal(.string("b")),
                                        "with": .literal(.string("B"))
                                    ]))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("fixed")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(sut, arguments: ["line": .string("a,b,c")])

        // Then
        #expect(outputs["result"] == .string("a / B / c"))
    }

    @Test("what a word answers is declared, so the link reads it")
    func standardAnswersAreDeclared() throws {
        // Given — `count` declares that it answers an int, and `split` declares
        // that it is sent a string
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "items": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(selector: "count", arguments: [
                                        "of": .reference([.key("items")])
                                    ]))
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "split", arguments: [
                                        "of": .reference([.key("many")]),
                                        "value": .literal(.string(","))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("bytes do not order")
    func bytesDoNotOrder() async throws {
        // Given — bytes are an opaque value: equal or not, counted, and
        // nothing else. `Comparable` does not admit them, and a literal is a
        // reading the link can judge, so the refusal lands before the run.
        let sut = Warp.Expression.dispatch(
            Dispatch(
                receiver: .literal(.bytes([0x01])),
                selector: "lessThan",
                arguments: ["value": .literal(.bytes([0x02]))]
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [Statement(id: "probe", expression: sut)], result: reference("probe"))
        } throws: { error in
            error is LinkError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("a walk hands a null element over as the element it is")
    func aWalkCarriesNullElements() async throws {
        // Given — `map` offers each element to the procedure it was given, and
        // an element that is null was still an element of the collection
        let sut = Warp.Expression.dispatch(
            Dispatch(
                receiver: .literal(.array([.int(1), .null])),
                selector: "std.collection.map",
                arguments: [
                    "value": .closure(
                        Procedure(
                            signature: Signature(
                                parameters: ["item": Parameter(type: .any)]
                            ),
                            body: [],
                            result: reference("item")
                        )
                    )
                ]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .array([.int(1), .null]))
    }

    @Test("two spellings of one text are one value")
    func stringsCompareAsAPersonReads() async throws {
        // Given — Unicode writes `é` two ways, and the two are different bytes.
        // A name is held to one spelling (normal form C), but a string value
        // arrives from the world spelled however the world spelled it — so
        // equality reads the text the way a person does, not the bytes.
        let sut = Warp.Expression.dispatch(
            Dispatch(
                receiver: .literal(.string("caf\u{E9}")),
                selector: "equal",
                arguments: ["value": .literal(.string("cafe\u{301}"))]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .bool(true))
    }

    @Test("a whole and a fraction meet exactly at every size")
    func wholeAndFractionMeetExactly() throws {
        // Given — 2^53 + 1 rounds to 2^53 in binary64, so a judgment that
        // converts would call two different worths the same. Worth does not
        // follow the rounding, in any consumer of the one order.
        let above = Value.int(9007199254740993)
        let below = Value.double(9007199254740992.0)

        // When / Then
        #expect(!above.matches(below))
        #expect(Value.int(9007199254740992).matches(below))
        #expect(Value.order(above, below) == .orderedDescending)
        #expect(Value.order(below, above) == .orderedAscending)
        #expect(Value.order(.int(-2), .double(-2.5)) == .orderedDescending)
        #expect(Value.order(.int(.max), .double(0x1p63)) == .orderedAscending)
        #expect(Value.order(.int(.min), .double(-0x1p63)) == .orderedSame)
        #expect(Value.order(.int(0), .double(.nan)) == nil)

        // min and max pick between the values as they arrived — the int wins
        // here, and no conversion flattens it into a tie.
        let picked = try ComparisonQuery(.max).evaluate(
            Question(receiver: above, arguments: ["value": below])
        )

        #expect(picked == above)
    }

    @Test("what orders with nothing is not sorted around")
    func aFractionThatIsNotANumberRefusesToSort() {
        // Given — NaN answers no comparison, so any placement of it would be
        // an order sorted could not answer for; refused, the way a mixed
        // array is, rather than placed arbitrarily
        #expect {
            try BuildingQuery(.sorted).evaluate(
                Question(receiver: .array([.double(1.5), .double(.nan)]))
            )
        } throws: { error in
            "\(error)".contains("ordering with the rest")
        }
    }

    // MARK: - Control

    @Test("abort refuses carrying its rendered message")
    func abortRefusesWithItsMessage() async throws {
        // Given
        let sut = refusing(interpolated(literal("no: "), spelling(reference("reason"))))

        // When / Then — nameless and last, with no result: nothing may be
        // written after what never finishes, so the procedure ends with it
        await #expect {
            try await run(
                Procedure(
                    signature: Signature(parameters: ["reason": Parameter(type: .string)]),
                    body: [Statement(expression: sut)]
                ),
                arguments: ["reason": .string("out of room")]
            )
        } throws: { error in
            (error as? Aborted)?.message == "no: out of room"
        }
    }

    @Test("a refusal is caught by an attempt around it")
    func abortIsRecoverable() async throws {
        // Given — `RecoverableFailure` is what separates the world refusing from
        // the author being wrong, and a refusal is the first kind
        let sut = Warp.Expression.attempt(
            Block(body: [Statement(expression: refusing(literal("stopped")))]),
            rescue: Block(body: [], result: .literal(.string("caught"))),
            failure: "failure"
        )

        // When
        let answered = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answered == .string("caught"))
    }

    @Test("an arm that refuses does not decide what the arm that stays holds")
    func refusalDoesNotWidenTheOtherArm() throws {
        // Given — `returns: never` is what keeps the branch a string. Were it
        // `any`, the consumer below would be allowed to disagree with it.
        let sut = try Module(
            name: "app",
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ok": Parameter(type: .bool)]),
                    body: [
                        Statement(
                            id: "either",
                            binding: .variable,
                            expression: .literal(.null)
                        ),
                        Statement(
                            expression: .conditional(
                                reference("ok"),
                                then: [
                                    Statement(
                                        id: "either",
                                        binding: .assignment,
                                        expression: .literal(.string("here"))
                                    )
                                ],
                                else: [Statement(expression: refusing(literal("gone")))]
                            )
                        ),
                        Statement(
                            id: "used",
                            expression: .dispatch(
                                Dispatch(selector: "wants", arguments: ["it": reference("either")])
                            )
                        )
                    ],
                ),
                "wants": Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then — the branch holds a string, and `wants` declares an int
        #expect(throws: LinkError.self) {
            try linker.link([sut] + Module.standard, entry: entryName)
        }
    }
}

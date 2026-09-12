//
//  StandardTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpStandard

// The procedures that ship in bundles, and the fact that they are bundles: a caller
// takes the ones its programs have use for, and a name from a bundle it left out
// does not resolve.
@Suite("The standard vocabulary")
struct StandardTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a bundle left out is a bundle whose names do not resolve")
    func aBundleLeftOutDoesNotResolve() throws {
        // Given. A program that only counts, linked without the bundle that
        // declares counting
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(
                                receiver: .literal(.array([.int(1)])),
                                selector: "std.collection.count"
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: BuildError.self) {
            try builder.build([sut, .math, .text, .foundation], entry: entryName)
        }

        #expect(throws: Never.self) {
            try builder.build([sut, .collection, .foundation], entry: entryName)
        }
    }

    @Test("a connective leaves the rest unasked once the answer is settled")
    func connectivesShortCircuit() async throws {
        // Given. The later side divides by zero, which refuses when it is
        // asked. `all` is settled by the first false, so it never is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .constant("verdict"), expression: every(
                                equals(.literal(.int(1)), .literal(.int(2))),
                                equals(
                                    .call(Call(
                                        receiver: .literal(.int(1)),
                                        selector: "std.math.dividedBy",
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

    @Test("a procedure takes a procedure the author wrote and runs it")
    func aWalkTakesAProcedure() async throws {
        // Given. Map, filter and reduce are declarations rather than
        // constructs. Nothing in the grammar knows they exist
        let doubling = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .int),
            body: [],
            result: .call(Call(
                receiver: reference("item"),
                selector: "std.math.times",
                arguments: ["value": .literal(.int(2))]
            ))
        )
        let odd = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .bool),
            body: [
                Statement(binding: .constant("left"), expression: .call(Call(
                        receiver: reference("item"),
                        selector: "std.math.remainder",
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
            result: .call(Call(
                receiver: reference("carried"),
                selector: "std.math.plus",
                arguments: ["value": reference("item")]
            ))
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ns": Parameter(type: .array(.int))]),
                    body: [
                        Statement(binding: .constant("doubled"), expression: .call(Call(
                                receiver: reference("ns"),
                                selector: "std.collection.map",
                                arguments: ["value": .closure(doubling)]
                            ))
                        ),
                        Statement(binding: .constant("kept"), expression: .call(Call(
                                receiver: reference("ns"),
                                selector: "std.collection.filter",
                                arguments: ["value": .closure(odd)]
                            ))
                        ),
                        Statement(binding: .constant("total"), expression: .call(Call(
                                receiver: reference("ns"),
                                selector: "std.collection.reduce",
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
            answer == .dictionary([
                "doubled": .array([.int(2), .int(4), .int(6)]),
                "kept": .array([.int(1), .int(3)]),
                "total": .int(6)
            ])
        )
    }

    @Test("a walk declares what it hands over, and a body reads what it wants")
    func aWalkOffersRatherThanRequires() async throws {
        // Given. `reduce` hands over `carried` and `item`. Counting only needs
        // the first, and declaring the second to leave it unread would be a
        // declaration the author never meant
        let counting = Procedure(
            signature: Signature(
                parameters: ["carried": Parameter(type: .int)],
                returns: .int
            ),
            body: [],
            result: .call(Call(
                receiver: reference("carried"),
                selector: "std.math.plus",
                arguments: ["value": .literal(.int(1))]
            ))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ns": Parameter(type: .array(.int))]),
                    body: [],
                    result: .call(Call(
                        receiver: reference("ns"),
                        selector: "std.collection.reduce",
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
        // Given. `map` declares `pure procedure`, so a body that shouts is
        // refused before any run rather than suspending inside a path
        let loud = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .string)]),
            body: [],
            result: .call(Call(
                selector: "app.shout",
                arguments: ["text": reference("item")]
            ))
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["names": Parameter(type: .array(.string))]),
                    body: [],
                    result: .call(Call(
                        receiver: reference("names"),
                        selector: "std.collection.map",
                        arguments: ["value": .closure(loud)]
                    ))
                )
            ]
        )

        // When / Then
        #expect(throws: BuildError.self) {
            try builder.build([sut, .shouting] + Module.standard, entry: entryName)
        }
    }

    @Test("a divisor of zero refuses rather than taking the process")
    func divisionByZeroRefuses() async throws {
        // Given. Both are Swift traps if the answer is taken rather than
        // judged, and each arrives at run time
        let asks: [(Name, Value, Value)] = [
            ("std.math.remainder", .int(5), .int(0)),
            ("std.math.dividedBy", .int(5), .int(0))
        ]

        for (procedure, receiver, operand) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .call(Call(
                            receiver: .literal(receiver),
                            selector: procedure,
                            arguments: ["value": .literal(operand)]
                        ))
                    )
                ]
            )

            // When / Then
            await #expect(throws: ExecutionError.self, "\(procedure) took the process") {
                try await run(sut)
            }
        }
    }

    @Test("arithmetic off the procedure's edge is a fault, not a wrap")
    func wholeArithmeticOverflowFaults() async throws {
        // Given. Each of these falls off the edge of the int, and the
        // language stops rather than answering a number the digits do not say
        let asks: [(Name, Value, Value)] = [
            ("std.math.times", .int(Int.max), .int(2)),
            ("std.math.plus", .int(Int.max), .int(1)),
            ("std.math.minus", .int(Int.min), .int(1))
        ]

        func asking(_ procedure: Name, _ receiver: Value, _ operand: Value) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .call(Call(
                            receiver: .literal(receiver),
                            selector: procedure,
                            arguments: ["value": .literal(operand)]
                        ))
                    )
                ]
            )
        }

        for (procedure, receiver, operand) in asks {
            // When / Then
            await #expect(throws: ExecutionError.self, "\(procedure) answered") {
                try await run(asking(procedure, receiver, operand))
            }
        }

        // `Int.min remainder -1` trips the hardware's division, but the
        // remainder itself is 0. An answer the procedure holds, so it answers.
        #expect(try await run(asking("std.math.remainder", .int(Int.min), .int(-1))) == .int(0))
    }

    @Test("a quotient is a fraction even between wholes")
    func aQuotientIsAFraction() async throws {
        // Given. DividedBy never answers an int; `floored` is where a whole
        // division's whole half is read back
        func divided(_ left: Int, _ right: Int) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .call(Call(
                            receiver: .literal(.int(left)),
                            selector: "std.math.dividedBy",
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

        // The quotient is binary64's own: each whole operand widens first (the
        // same widening every mixed operation performs) and the division rounds
        // once more. 2^53 + 1 widens to 2^53, and the answer is the widened
        // pair's, bit for bit.
        #expect(
            try await run(divided(9_007_199_254_740_993, 3))
                == .double(9_007_199_254_740_992.0 / 3.0)
        )
    }

    @Test("joined asked directly reads no default, since the default is the declaration's")
    func joinedAskedDirectlyRefusesAMissingSeparator() throws {
        // Given: asked outside a link, nothing fills the declaration's
        // default, and the procedure carries none of its own
        let sut = JoinedQuery()

        // When / Then
        #expect {
            try sut.evaluate(Question(receiver: .array([.string("a"), .string("b")])))
        } throws: { error in
            "\(error)".contains("asks a string separator, and null arrived")
        }
    }

    @Test("a codec keeps its own contract on the encoding name")
    func aCodecReadsItsEncodingArgument() throws {
        // Given. The declaration's enum says the same names early; this is the
        // implementation refusing a name it has no mapping for, so a drifted
        // declaration cannot make it answer in the wrong encoding
        let sut = DecodedQuery()

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
        // Given. The quotes must not change with the value's size: a number is
        // a number wherever it sits, and only text wears quotes
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.array([
                            .int(1),
                            .int(Int.max),
                            .string("9223372036854775807")
                        ])),
                        selector: "std.text.text"
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

    @Test("rounding and magnitude stop at the procedure's edge")
    func roundingPastTheIntFaults() async throws {
        // Given. A fraction whose whole part is past the int has no
        // int to answer, and the procedure's own minimum has no magnitude the procedure
        // holds. The refusal names the overflow, not a missing whole answer.
        // The two reasons are different facts.
        let asks: [(Name, Value)] = [
            ("std.math.floored", .double(1e30)),
            ("std.math.rounded", .double(1e30)),
            ("std.math.absolute", .int(Int.min))
        ]

        for (procedure, receiver) in asks {
            let sut = try Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .call(Call(
                            receiver: .literal(receiver),
                            selector: procedure
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
        // Given. `dividedBy` always answers a double, so a whole division is
        // that floored, and what it left over is `remainder`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["n": Parameter(type: .int)]),
                    body: [
                        Statement(binding: .constant("quotient"), expression: .call(Call(
                                receiver: reference("n"),
                                selector: "std.math.dividedBy",
                                arguments: ["value": .literal(.int(4))]
                            ))
                        ),
                        Statement(binding: .constant("whole"), expression: .call(Call(
                                receiver: reference("quotient"),
                                selector: "std.math.floored"
                            ))
                        ),
                        Statement(binding: .constant("left"), expression: .call(Call(
                                receiver: reference("n"),
                                selector: "std.math.remainder",
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
        #expect(answer == .dictionary(["whole": .int(2), "left": .int(3)]))
    }

    @Test("an array grows and shrinks, which is a length the text did not write")
    func anArrayIsBuiltRatherThanSpelled() async throws {
        // Given. A body walking a grid: the head moves and wraps, the trail
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
                        Statement(binding: .constant("stepped"), expression: .call(Call(
                                receiver: reference("head"),
                                selector: "std.math.plus",
                                arguments: ["value": .literal(.int(1))]
                            ))
                        ),
                        Statement(binding: .constant("wrapped"), expression: .call(Call(
                                receiver: reference("stepped"),
                                selector: "std.math.remainder",
                                arguments: ["value": reference("side")]
                            ))
                        ),
                        Statement(binding: .constant("grown"), expression: .call(Call(
                                receiver: reference("trail"),
                                selector: "std.collection.prepending",
                                arguments: ["value": reference("wrapped")]
                            ))
                        ),
                        Statement(binding: .constant("moved"), expression: .call(Call(
                                receiver: reference("grown"),
                                selector: "std.collection.dropLast"
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

        // When. The head sits at the last column, so stepping wraps it to 0
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
            answer == .dictionary([
                "grown": .array([.int(0), .int(3), .int(2), .int(1)]),
                "moved": .array([.int(0), .int(3), .int(2)])
            ])
        )
    }

    @Test("a dictionary is walked and rebuilt without naming its fields")
    func aDictionaryIsDataRatherThanAShape() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["counts": Parameter(type: .dictionary(.int))]),
                    body: [
                        Statement(binding: .constant("named"), expression: .call(Call(
                                receiver: reference("counts"),
                                selector: "std.collection.keys"
                            ))
                        ),
                        Statement(binding: .constant("held"), expression: .call(Call(
                                receiver: reference("counts"),
                                selector: "std.collection.values"
                            ))
                        ),
                        Statement(binding: .constant("changed"), expression: .call(Call(
                                receiver: reference("counts"),
                                selector: "std.collection.setting",
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
            arguments: ["counts": .dictionary(["a": .int(1), "b": .int(2)])]
        )

        // Then
        #expect(
            answer == .dictionary([
                "named": .array([.string("a"), .string("b")]),
                "held": .array([.int(1), .int(2)]),
                "changed": .dictionary(["a": .int(1), "b": .int(9)])
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
                        Statement(binding: .constant("sum"), expression: .call(Call(selector: "std.math.plus", arguments: [
                                        "of": .literal(.int(2)),
                                        "value": .literal(.int(3))
                                    ]))
                        ),
                        Statement(binding: .constant("product"), expression: .call(Call(selector: "std.math.times", arguments: [
                                        "of": .literal(.int(4)),
                                        "value": .literal(.double(2.5))
                                    ]))
                        ),
                        Statement(binding: .constant("quotient"), expression: .call(Call(selector: "std.math.dividedBy", arguments: [
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
                        Statement(binding: .constant("gone"), expression: .call(Call(selector: "std.math.dividedBy", arguments: [
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
        // Given. `{ of: x, lessThan: y }` is the condition grammar sending a
        // procedure, so ordering needed no grammar of its own
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "n": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("verdict"), expression: .literal(.string(""))
                        ),
                        Statement(
                            expression: .conditional(.call(Call(receiver: .reference([.key("n")]), selector: "std.math.lessThan", arguments: [
                                            "value": .literal(.int(10))
                                        ])), then: [
                                        Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("small"))
                                        )
                                    ], else: [
                                        Statement(binding: .assignment([.key("verdict")]), expression: .literal(.string("large"))
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

    @Test("text procedures compose the way a document writes them")
    func textProceduresCompose() async throws {
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
                        Statement(binding: .constant("parts"), expression: .call(Call(selector: "std.text.split", arguments: [
                                        "of": .reference([.key("line")]),
                                        "value": .literal(.string(","))
                                    ]))
                        ),
                        Statement(binding: .constant("rejoined"), expression: .call(Call(selector: "std.text.joined", arguments: [
                                        "of": .reference([.key("parts")]),
                                        "value": .literal(.string(" / "))
                                    ]))
                        ),
                        Statement(binding: .constant("fixed"), expression: .call(Call(selector: "std.text.replacing", arguments: [
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

    @Test("what a procedure answers is declared, so the build reads it")
    func standardAnswersAreDeclared() throws {
        // Given. `count` declares that it answers an int, and `split` declares
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
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "std.collection.count", arguments: [
                                        "of": .reference([.key("items")])
                                    ]))
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "std.text.split", arguments: [
                                        "of": .reference([.key("many")]),
                                        "value": .literal(.string(","))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: BuildError.self) {
            try builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("bytes do not order")
    func bytesDoNotOrder() async throws {
        // Given. Bytes are an opaque value: equal or not, counted, and nothing
        // else. `Comparable` does not admit them, and a literal is a reading
        // the build can judge, so the refusal lands before the run.
        let sut = Warp.Expression.call(
            Call(
                receiver: .literal(.bytes([0x01])),
                selector: "std.math.lessThan",
                arguments: ["value": .literal(.bytes([0x02]))]
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [Statement(binding: .constant("probe"), expression: sut)], result: reference("probe"))
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("a walk hands a null element over as the element it is")
    func aWalkCarriesNullElements() async throws {
        // Given. `map` offers each element to the procedure it was given, and
        // an element that is null was still an element of the collection
        let sut = Warp.Expression.call(
            Call(
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
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .array([.int(1), .null]))
    }

    @Test("two spellings of one text are one value")
    func stringsCompareAsAPersonReads() async throws {
        // Given. Unicode writes `é` two ways, and the two are different bytes.
        // A name is held to one spelling (normal form C), but a string value
        // arrives from the world spelled however the world spelled it, so
        // equality reads the text the way a person does, not the bytes.
        let sut = Warp.Expression.call(
            Call(
                receiver: .literal(.string("caf\u{E9}")),
                selector: "std.logic.equal",
                arguments: ["value": .literal(.string("cafe\u{301}"))]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .bool(true))
    }

    @Test("a whole and a fraction meet exactly at every size")
    func wholeAndFractionMeetExactly() throws {
        // Given. 2^53 + 1 rounds to 2^53 in binary64, so a judgment that
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

        // min and max pick between the values as they arrived. The int wins
        // here, and no conversion flattens it into a tie.
        let picked = try MaxQuery().evaluate(
            Question(receiver: above, arguments: ["value": below])
        )

        #expect(picked == above)
    }

    @Test("what orders with nothing is not sorted around")
    func aFractionThatIsNotANumberRefusesToSort() {
        // Given. NaN answers no comparison, so any placement of it would be an
        // order sorted could not answer for; refused, the way a mixed array is,
        // rather than placed arbitrarily
        #expect {
            try SortedQuery().evaluate(
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

        // When / Then. Nameless and last, with no result: nothing may be
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
        // Given. `RecoverableFailure` is what separates the world refusing from
        // the author being wrong, and a refusal is the first kind
        let sut = Warp.Expression.attempt(
            Block(body: [Statement(expression: refusing(literal("stopped")))]),
            rescue: Block(body: [], result: .literal(.string("caught"))),
            failure: "failure"
        )

        // When
        let answered = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answered == .string("caught"))
    }

    @Test("an arm that refuses does not decide what the arm that stays holds")
    func refusalDoesNotWidenTheOtherArm() throws {
        // Given. `returns: never` is what keeps the conditional a string. Were it
        // `any`, the consumer below would be allowed to disagree with it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ok": Parameter(type: .bool)]),
                    body: [
                        Statement(binding: .variable("either"), expression: .literal(.null)
                        ),
                        Statement(
                            expression: .conditional(
                                reference("ok"),
                                then: [
                                    Statement(binding: .assignment([.key("either")]), expression: .literal(.string("here"))
                                    )
                                ],
                                else: [Statement(expression: refusing(literal("gone")))]
                            )
                        ),
                        Statement(binding: .constant("used"), expression: .call(
                                Call(selector: "wants", arguments: ["it": reference("either")])
                            )
                        )
                    ],
                ),
                "app.wants": Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then. The conditional holds a string, and `wants` declares an int
        #expect(throws: BuildError.self) {
            try builder.build([sut] + Module.standard, entry: entryName)
        }
    }
}

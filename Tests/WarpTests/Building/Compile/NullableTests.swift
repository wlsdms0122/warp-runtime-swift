//
//  NullableTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp

// `T?`. The declared type or null, and the `?.` that reads through it.
@Suite
struct NullableTests {
    // MARK: - Property
    private let builder = Builder()
    private let entryName: Name = "entry"

    // MARK: - Test
    @Test("a nullable slot takes its value, null, and nothing else")
    func aNullableSlotSettles() throws {
        let declared = TypeExpression.nullable(.int)

        #expect(try declared.settling(.int(3), at: "limit") == .int(3))
        #expect(try declared.settling(.null, at: "limit") == .null)
        #expect(throws: (any Error).self) {
            try declared.settling(.string("x"), at: "limit")
        }
    }

    @Test("a block whose result is null holds no result, the way a document reads one")
    func aNullResultIsNoResult() {
        // Given / When
        let sut = Block(body: [], result: .literal(.null))

        // Then
        #expect(sut.result == nil)
    }

    @Test("what may be null does not stand where null was never declared")
    func aNullableReadingNeedsANullableSlot() throws {
        // The declared half fits its own slot, and the nullable does not. In
        // either wrapping.
        #expect(TypeExpression.nullable(.int).accepts(.int))
        #expect(TypeExpression.nullable(.int).accepts(.null))
        #expect(TypeExpression.nullable(.int).accepts(.nullable(.int)))
        #expect(!TypeExpression.int.accepts(.nullable(.int)))
        #expect(!TypeExpression.nullable(.int).accepts(.string))
        #expect(!TypeExpression.nullable(.int).accepts(.nullable(.string)))
    }

    @Test("a nullable reading is refused where the plain type is declared")
    func aNullableReadingIsRefusedAtACall() async throws {
        // Given. The `?.` path answers `int?`, and the callee declares `int`
        let sut = try Module(
            procedures: [
                "half": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(0))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .nullable(.record(["size": .int]))
                            )
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .reference([.key("task"), .key("size", optional: true)])
                        )
                    ],
                    result: .call(Call(selector: "half", arguments: [.reference([.key("read")])]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("holds int?")
        }
    }

    @Test("the optional dot on a record field reads it, and its answer may be null")
    func anOptionalDotOverANullable() async throws {
        // Given. The record may be null, so `?.` is the only spelling that
        // links; what it answers is the field or null
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .nullable(.record(["size": .int]))
                            )
                        ],
                        returns: .nullable(.int)
                    ),
                    body: [],
                    result: .reference([.key("task"), .key("size", optional: true)])
                )
            ]
        )

        // When / Then. The value that arrived reads its field, and the null the
        // caller handed answers null
        #expect(try await run(sut, arguments: ["task": .dictionary(["size": .int(7)])]) == .int(7))
        #expect(try await run(sut, arguments: ["task": .null]) == .null)
    }

    @Test("a name that is statically null is not read through")
    func aStaticNullRefusesTheRead() async throws {
        // Given. The binding holds null and nothing else, so every dot after it
        // reads through null and the build says so
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("gone"), expression: .literal(.null))
                    ],
                    result: .reference([.key("gone"), .key("name")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("reads through null")
        }
    }

    @Test("a nullable parameter takes null without leaning on a default")
    func aNullableParameterTakesNullByType() async throws {
        // Given. `T?` says null is a value, so the boundary lets it in the way
        // the build does: no `default: null` crutch required
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "limit", type: .nullable(.int))],
                        returns: .nullable(.int)
                    ),
                    body: [],
                    result: .reference([.key("limit")])
                )
            ]
        )

        // When / Then. A value arrives as itself and a null as null. A
        // parameter given nothing is refused, nullable or not
        #expect(try await run(sut, arguments: ["limit": .int(5)]) == .int(5))
        #expect(try await run(sut, arguments: ["limit": .null]) == .null)
        await #expect {
            try await run(sut)
        } throws: { error in
            "\(error)".contains("nothing was given for limit")
        }

        // A plain typed parameter still means "give me something".
        let plain = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "limit", type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("limit")])
                )
            ]
        )

        await #expect(throws: (any Error).self) {
            try await run(plain)
        }
    }

    @Test("a written call hands a nullable argument like any other")
    func aNullableArgumentIsHanded() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "labelled": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .string),
                            Parameter(name: "limit", type: .nullable(.int))
                        ],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([.key("of")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "procedure", type: .string)],
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("called"), expression: .call(Call(
                            selector: "labelled",
                            arguments: [.reference([.key("procedure")])]
                        ))
                        )
                    ],
                    result: .reference([.key("called")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'labelled' 1 arguments, and it takes 2")
        }
    }

    @Test("a constant's dots are judged like a body's")
    func aConstantPathIsJudged() async throws {
        // Given. The constant is a record, so a field it does not carry is the
        // link's refusal, not a run's surprise
        let sut = try Module(
            constants: ["config": .record(["host": .literal(.string("a"))])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .reference([.key("config"), .key("port")])
                )
            ]
        )

        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("a ? that says nothing refuses behind a name too")
    func aNeedlessNullableBehindAnAliasIsRefused() async throws {
        // Given. The reader refuses `any?` by spelling; a name may hide the
        // same type, and the rule is the model's, held where names resolve
        let hidingAny = try Module(
            types: ["Loose": .any],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "value", type: .nullable(.named("Loose")))
                        ]
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        await #expect {
            try await builder.build([hidingAny] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("writes `?`")
        }

        // And a nullable behind the name (`B = int?`, then `B?`) is the doubled
        // `?` by another spelling.
        let hidingNullable = try Module(
            types: ["Maybe": .nullable(.int)],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "value", type: .nullable(.named("Maybe")))
                        ]
                    ),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        await #expect {
            try await builder.build([hidingNullable] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("writes `?`")
        }
    }

    @Test("what a nullable unwraps to is judged like any other type")
    func anUnwrapIsJudgedAgain() async throws {
        // Given. `Task?` unwraps to a declared record through its name, and the
        // record's rules hold after the unwrap: the declared field reads, the
        // undeclared one refuses
        let sut = try Module(
            types: ["Task": .record(["name": .string])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .nullable(.named("Task")))
                        ],
                        returns: .nullable(.string)
                    ),
                    body: [],
                    result: .reference([.key("task"), .key("name", optional: true)])
                )
            ]
        )

        #expect(
            try await run(sut, arguments: ["task": .dictionary(["name": .string("a")])])
                == .string("a")
        )
        #expect(try await run(sut, arguments: ["task": .null]) == .null)
    }

    @Test("a nullable type spells itself in refusals")
    func aNullableRenders() {
        #expect(TypeExpression.nullable(.int).rendered == "int?")
        #expect(TypeExpression.nullable(.array(.string)).rendered == "array<string>?")
    }

    @Test("a ?. that could not have read past anything is refused")
    func aNeedlessOptionalDotIsRefused() async throws {
        // Given. The field is proven present, so the spelling that expects
        // absence says nothing, the way `int??` says nothing on a type
        let onAField = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .record(["id": .string]))
                        ]
                    ),
                    body: [],
                    result: .reference([.key("task"), .key("id", optional: true)])
                )
            ]
        )

        await #expect {
            try await builder.build([onAField] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("read with `.`")
        }
    }

    @Test("a plain index into a nullable refuses toward the optional bracket")
    func aPlainIndexIntoANullableRefuses() async throws {
        // Given. The array may be null, and `[` does not read absence; the
        // refusal points at the spelling that does
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .nullable(.array(.string)))
                        ]
                    ),
                    body: [],
                    result: .reference([.key("items"), .index(0)])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("Absence is read with `?[`")
        }
    }

    @Test("the optional index reads a nullable array")
    func anOptionalIndexOverANullable() async throws {
        // Given. An array or null; `?[0]` reads the element that arrived and
        // answers null for the null, so the path's answer is nullable
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .nullable(.array(.string)))
                        ],
                        returns: .nullable(.string)
                    ),
                    body: [],
                    result: .reference([.key("items"), .index(0, optional: true)])
                )
            ]
        )

        // When / Then
        #expect(try await run(
            sut,
            arguments: ["items": .array([.string("first")])]
        ) == .string("first"))
        #expect(try await run(sut, arguments: ["items": .null]) == .null)
    }

    @Test("the optional index does not read past the end")
    func anOptionalIndexStillRefusesPastTheEnd() async throws {
        // Given. `?[` expects the array's absence, not the element's: past the
        // end is a defect the array's own length proves, `?[` or not
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .nullable(.array(.string)))
                        ],
                        returns: .nullable(.string)
                    ),
                    body: [],
                    result: .reference([.key("items"), .index(5, optional: true)])
                )
            ]
        )

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await run(sut, arguments: ["items": .array([.string("only")])])
        }
    }

    @Test("a needless optional index is refused at the build")
    func aNeedlessOptionalIndexRefuses() async throws {
        // Given. The array is proven non-null, so `?[` claims an absence the
        // types rule out, the way a needless `?.` does
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string))
                        ]
                    ),
                    body: [],
                    result: .reference([.key("items"), .index(0, optional: true)])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("never null")
        }
    }

    @Test("a mark on the head is refused wherever a path is judged")
    func aMarkedHeadIsRefused() async throws {
        // Given (the head is a name a scope holds, so there is nothing before
        // it that could have been absent; a document never spells this, and a
        // frontend that builds segments directly is told so When / Then) the
        // check meets it first, so there is no such module to take to a link
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(
                            parameters: [
                                Parameter(name: "items", type: .array(.string))
                            ]
                        ),
                        body: [],
                        result: .reference([.key("items", optional: true), .index(0)])
                    )
                ]
            )
        } throws: { error in
            "\(error)".contains("marks the head optional")
        }

        // And the run says the same rather than reading past it. The layers
        // share one sentence, so neither answers what the other refuses
        let marked: Path = [.key("items", optional: true), .index(0)]
        let resolver = Folding(bindings: ["items": .array([.string("one")])], natives: [])

        await #expect {
            try await resolver.read(marked, at: .given("test"))
        } throws: { error in
            "\(error)".contains(marked.markedHead ?? "")
        }
    }

    @Test("an optional index reference reads its name at the exit that indexes")
    func anOptionalIndexReferenceOverANullable() async throws {
        // Given. `items?[i]`: the index is a name the run settles, and the null
        // that short-circuits before it never reads the name at all
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "items", type: .nullable(.array(.string)))
                        ],
                        returns: .nullable(.string)
                    ),
                    body: [],
                    result: .reference([
                        .key("items"),
                        .indexRef([.key("i")], optional: true)
                    ])
                )
            ]
        )

        // When / Then
        #expect(try await run(
            sut,
            arguments: ["i": .int(1), "items": .array([.string("a"), .string("b")])]
        ) == .string("b"))
        #expect(try await run(sut, arguments: ["i": .int(1), "items": .null]) == .null)
    }
}

// The dot judged behind an index reference. The walk continues through `[i]`
// the way it does through `[0]`, so nothing after one escapes the build.
@Suite
struct IndexReferenceJudgmentTests {
    // MARK: - Property
    private let builder = Builder()
    private let entryName: Name = "entry"

    // MARK: - Test
    @Test("a constant does not run a body its own document declares")
    func aConstantDoesNotRunAWrittenBody() async throws {
        // Given. `shout` has a written body, still being resolved beside the
        // constants it may read; a constant that runs it is a cycle with no
        // start, refused out loud
        let sut = try Module(
            constants: [
                "loud": .call(Call(selector: "shout", arguments: [.literal(.string("hi"))]))
            ],
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([.key("of")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .reference([.key("loud")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("a circle with no start")
        }
    }

    @Test("a body's constant-headed call runs a written procedure, resolved")
    func aBodyFoldsThroughAWrittenProcedure() async throws {
        // Given. The constants are settled and the procedures resolved by the time a
        // body folds, so a constant-headed call may run a written procedure: the
        // cycle the settling refuses is the constants' own
        let sut = try Module(
            constants: ["greeting": .literal(.string("hi"))],
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(selector: "std.collection.count", arguments: [reference("of")]))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "shout", arguments: [reference("greeting")]))
                )
            ]
        )

        // When / Then. Folded at the build to the value the resolved body
        // answers
        #expect(try await run(sut) == .int(2))
    }

    @Test("whether a body links is its own text's fact, whoever calls it")
    func linkabilityDoesNotDependOnCallers() async throws {
        // Given. `helper` folds a constant-headed call through a written procedure; a procedure
        // (`loud`) that happens to call `helper` must not change what `helper`
        // means, because nothing about `helper`'s text changed
        let procedures: [Name: Procedure] = [
            "shout": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "of", type: .string)],
                    returns: .int
                ),
                body: [],
                result: .call(Call(selector: "std.collection.count", arguments: [reference("of")]))
            ),
            "helper": Procedure(
                signature: Signature(returns: .int),
                body: [],
                result: .call(Call(selector: "shout", arguments: [reference("greeting")]))
            ),
            "loud": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "of", type: .int)],
                    returns: .int
                ),
                body: [],
                result: .call(Call(selector: "helper"))
            ),
            entryName: Procedure(
                access: .public,
                signature: Signature(returns: .int),
                body: [],
                result: .call(Call(selector: "helper"))
            )
        ]

        let sut = try Module(
            constants: ["greeting": .literal(.string("hi"))],
            procedures: procedures
        )

        // When / Then. Links and answers, `loud` present or not
        #expect(try await run(sut) == .int(2))

        var without = procedures
        without["loud"] = nil

        #expect(
            try await run(try Module(
                constants: ["greeting": .literal(.string("hi"))],
                procedures: without
            )) == .int(2)
        )
    }

    @Test("a closure parameter may not take a constant's name")
    func aClosureParameterDoesNotShadowAConstant() throws {
        // Given. Compiling folds a constant wherever its name is read, so a
        // closure parameter under that name would never be the one that
        // answers; refused where the top-level signature's is
        let procedure = Procedure(
            signature: Signature(),
            body: [
                Statement(binding: .constant("f"), expression: .closure(Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "greeting", type: .string)]
                        ),
                        body: [],
                        result: .reference([.key("greeting")])
                    ))
                )
            ],
            result: .literal(.int(1))
        )

        // When / Then. There is no such module to hand anywhere: making one is
        // what refuses
        #expect {
            try Module(
                constants: ["greeting": .literal(.string("hi"))],
                procedures: [entryName: procedure]
            )
        } throws: { error in
            "\(error)".contains("take the place of")
        }
    }

    @Test("a closure a constant holds has its sends checked")
    func aConstantClosureIsChecked() async throws {
        // Given. The closure runs later, so evaluating the constant proves
        // nothing about the call inside it; the gate every gathered call passes
        // catches the argument no parameter stands to take
        let sut = try Module(
            constants: [
                "f": .closure(Procedure(
                    signature: Signature(returns: .string),
                    body: [],
                    result: .call(Call(
                        selector: "std.text.uppercased",
                        arguments: [.literal(.string("a")), .literal(.bool(true))]
                    ))
                ))
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .reference([.key("f")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'std.text.uppercased' 2 arguments, and it takes 1")
        }
    }

    @Test("a constant index inside an index reference folds, however deep")
    func nestedConstantIndexReferencesFold() async throws {
        // Given. `items[names[C]]`: the inner index reads a constant, and no
        // constant name survives into the image at any depth
        let sut = try Module(
            constants: ["C": .literal(.int(0))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string)),
                            Parameter(name: "names", type: .array(.int))
                        ],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([
                        .key("items"),
                        .indexRef([.key("names"), .indexRef([.key("C")])])
                    ])
                )
            ]
        )

        // When / Then
        #expect(
            try await run(
                sut,
                arguments: [
                    "items": .array([.string("a"), .string("b")]),
                    "names": .array([.int(1)])
                ]
            ) == .string("b")
        )
    }

    @Test("an undeclared field behind an index reference refuses at the build")
    func anUndeclaredFieldBehindAnIndexReferenceRefuses() async throws {
        // Given. The element type is known whatever the index is, so the absent
        // field is the build's to refuse
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "items", type: .array(.record(["id": .string])))
                        ]
                    ),
                    body: [],
                    result: .reference([
                        .key("items"),
                        .indexRef([.key("i")]),
                        .key("nope")
                    ])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("an index reference that provably is not a number refuses at the build")
    func anIndexReferenceReadingIsJudged() async throws {
        // Given. `name` is text, and an index is a whole number; the text
        // proves the defect, so the build refuses it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string)),
                            Parameter(name: "name", type: .string)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("items"), .indexRef([.key("name")])])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("expected int")
        }
    }

    @Test("a const body nobody reaches still has its sends checked")
    func anUnreachedConstBodyIsChecked() async throws {
        // Given. `shout` is derivable, so its body lands in the image and runs
        // whenever a path reaches it; a call it writes wrongly is the build's to
        // refuse whether or not the entry ever mentions it
        let sut = try Module(
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .string)],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "std.text.uppercased",
                        arguments: [.reference([.key("of")]), .literal(.bool(true))]
                    ))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then. `uppercased` takes one argument and is sent two
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'std.text.uppercased' 2 arguments, and it takes 1")
        }
    }

    @Test("an index reference into what is not an array refuses like an index")
    func anIndexReferenceNeedsAnArray() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "procedure", type: .string)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("procedure"), .indexRef([.key("i")])])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("only an array or a dictionary is indexed")
        }
    }
}

// A dot on a type parameter. The type is the call's fact, so the build leaves
// the segments as written rather than judging on nothing.
@Suite
struct ParameterDotTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Test
    @Test("a dot on some T reads the field the call filled in")
    func aDotOnAParameterReadsData() async throws {
        // Given. The procedure's body reads `of.count`; the call fills T with a
        // record carrying `count`, and the field wins because nothing here ever
        // judged the dot a procedure
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .parameter(name: "T"))],
                        returns: .any
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("count")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(selector: "peek", arguments: [.record(["count": .literal(.string("mine"))])]))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .string("mine"))
    }

    @Test("naming a step through a parameter does not change what the path means")
    func aNamedStepStillReadsOn() async throws {
        // Given. `of.inner.count` written as two statements. The step is a
        // type the call decides, the way the parameter is, so the dot after it
        // stands as written and the call's value answers it
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .parameter(name: "T"))],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("held"), expression: .reference([.key("of"), .key("inner")])
                        )
                    ],
                    result: .reference([.key("held"), .key("count")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .record([
                                "inner": .record(["count": .literal(.string("mine"))])
                            ])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .string("mine"))
    }

    @Test("what was read out of a parameter is not the parameter")
    func aStepIsNotTheParameterItCameThrough() async throws {
        // Given. One name written twice: once the parameter, once a field of
        // it. They are two unknowns, not one (`of` is the type the call filled
        // in and `of.inner` is a field of that type) so the name holds neither
        // reading and a dot on it is refused.
        //
        // Read as the same parameter, this linked: a field stood where `some T`
        // was proven, which is the impersonation. A bound would have ridden
        // along with it. `some N: Comparable` proving `of.inner` comparable on
        // nothing but where it was read from.
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "flag", type: .bool),
                            Parameter(name: "of", type: .parameter(name: "T"))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .reference([.key("of")])
                        ),
                        Statement(
                            expression: .conditional(
                                equals(.reference([.key("flag")]), .literal(.bool(true))),
                                then: [
                                    Statement(binding: .assignment([.key("held")]), expression: .reference([.key("of"), .key("inner")])
                                    )
                                ],
                                else: nil
                            )
                        )
                    ],
                    result: .reference([.key("held"), .key("count")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .literal(.bool(true)),
                            .record(["inner": .record(["count": .literal(.string("mine"))])])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which declares nothing")
        }
    }

    @Test("one field is one type, however the walk that reached it was marked")
    func aMarkDoesNotSplitTheField() async throws {
        // Given. The same field of the same parameter, reached once plainly and
        // once through a mark. What a mark says is expected of the value; where
        // the walk landed is the field either way, so the two readings are one
        // type and a dot on it stands.
        //
        // Held as the path and not as its spelling for exactly this: `of.inner`
        // and `of?.inner` spell apart, and a name would have made one field
        // into two unknowns that never meet. The dot after them refused, for no
        // reason an author could see.
        func module(marking: Bool) throws -> Module {
            try Module(
                procedures: [
                    "peek": Procedure(
                        signature: Signature(
                            parameters: [
                                Parameter(name: "flag", type: .bool),
                                Parameter(name: "of", type: .parameter(name: "T"))
                            ],
                            returns: .any
                        ),
                        body: [
                            Statement(binding: .variable("held"), expression: .reference([.key("of"), .key("inner")])
                            ),
                            Statement(
                                expression: .conditional(
                                    equals(.reference([.key("flag")]), .literal(.bool(true))),
                                    then: [
                                        Statement(binding: .assignment([.key("held")]), expression: .reference([
                                                .key("of"),
                                                .key("inner", optional: marking)
                                            ])
                                        )
                                    ],
                                    else: nil
                                )
                            )
                        ],
                        result: .reference([.key("held"), .key("count")])
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .any),
                        body: [],
                        result: .call(Call(
                            selector: "peek",
                            arguments: [
                                .literal(.bool(true)),
                                .record(["inner": .record(["count": .literal(.int(1))])])
                            ]
                        ))
                    )
                ]
            )
        }

        // When / Then. Written the same way twice, and written two ways, link
        // alike
        for marking in [false, true] {
            _ = try await builder.build([module(marking: marking)] + Module.standard)
        }
    }

    @Test("naming a step on the way does not make it a second unknown")
    func aNamedStepArrivesWhereTheWalkArrives() async throws {
        // Given. The same field of the same parameter, reached once in a single
        // walk and once through a name given to a step along the way. A body
        // may hold what it read, and holding it is not reading something else.
        //
        // Rooted at the local name, `held.count` and `of.inner.count` were two
        // unknowns: the pair met at a join, held neither, and the dot after
        // was refused. The root is the parameter, so a name in between changes
        // nothing about where the walk landed.
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "flag", type: .bool),
                            Parameter(name: "of", type: .parameter(name: "T"))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("held"), expression: .reference([.key("of"), .key("inner")])),
                        Statement(binding: .variable("seen"), expression: .reference([.key("of"), .key("inner"), .key("count")])
                        ),
                        Statement(expression: .conditional(
                            equals(.reference([.key("flag")]), .literal(.bool(true))),
                            then: [Statement(binding: .assignment([.key("seen")]), expression: .reference([.key("held"), .key("count")])
                            )],
                            else: nil
                        ))
                    ],
                    result: .reference([.key("seen"), .key("deep")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .literal(.bool(true)),
                            .record([
                                "inner": .record(["count": .record(["deep": .literal(.int(1))])])
                            ])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("one unknown is one unknown, whichever parameter it was read through")
    func oneUnknownIsReadThroughEitherParameter() async throws {
        // Given. Two parameters of the same type parameter. A call fills `T`
        // once, so they hold one type, and the same field of it read through
        // either name is the same field.
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "also", type: .parameter(name: "T")),
                            Parameter(name: "flag", type: .bool),
                            Parameter(name: "of", type: .parameter(name: "T"))
                        ],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .variable("seen"), expression: .reference([.key("of"), .key("inner")])
                        ),
                        Statement(expression: .conditional(
                            equals(.reference([.key("flag")]), .literal(.bool(true))),
                            then: [Statement(binding: .assignment([.key("seen")]), expression: .reference([.key("also"), .key("inner")])
                            )],
                            else: nil
                        ))
                    ],
                    result: .reference([.key("seen"), .key("count")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [
                            .record(["inner": .record(["count": .literal(.int(2))])]),
                            .literal(.bool(true)),
                            .record(["inner": .record(["count": .literal(.int(1))])])
                        ]
                    ))
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a type read out of a body is not a declaration anybody can write")
    func aReadingIsRefusedWhereADeclarationGoes() async throws {
        // Given. A declaration assembled in the host claiming what only a walk
        // produces. No document spells one, and the build refuses it where it
        // was written rather than letting it stand: a declaration says what a
        // call fills, and nothing fills a path only one body can read.
        //
        // The two are apart in the type, so this is a refusal about what was
        // written and not a name that happened to collide.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .reading(of: "T", path: [.key("inner")]))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("read out of a body")
        }
    }
}

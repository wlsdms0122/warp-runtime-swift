//
//  InferenceTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// An author binds a call to a name and passes the name, so a declared answer
// only reaches the next call site if the build knows what that name holds. These
// are the places knowing it turns two declarations into a refusal before
// anything runs.
@Suite("What the build knows a name holds")
struct InferenceTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a type parameter carries the element type through the call that filled it")
    func aTypeParameterCarriesWhatFilledIt() async throws {
        // Given. `first` takes `Array<some Element>` and answers `some
        // Element`, so what it answers here is a string and the declaration
        // never said so
        let wants = Procedure(
            signature: Signature(parameters: [Parameter(name: "text", type: .string)]),
            body: []
        )
        let sut = try Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "names", type: .array(.string))]
                    ),
                    body: [
                        Statement(binding: .constant("head"), expression: .call(Call(
                            selector: "Standard.Collection.first",
                            arguments: [reference("names")]
                        ))),
                        Statement(binding: .constant("asked"), expression: .call(Call(
                            selector: "wants",
                            arguments: [reference("head")]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard)
        }
    }

    @Test("a type parameter filled with one type refuses a call wanting another")
    func aFilledTypeParameterRefusesWhatDisagrees() async throws {
        // Given. The same walk, over an array of ints
        let wants = Procedure(
            signature: Signature(parameters: [Parameter(name: "text", type: .string)]),
            body: []
        )
        let sut = try Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "counts", type: .array(.int))]
                    ),
                    body: [
                        Statement(binding: .constant("head"), expression: .call(Call(
                            selector: "Standard.Collection.first",
                            arguments: [reference("counts")]
                        ))),
                        Statement(binding: .constant("asked"), expression: .call(Call(
                            selector: "wants",
                            arguments: [reference("head")]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds Int where String is declared")
        }
    }

    @Test("a type parameter a procedure answers becomes what the walk answers")
    func aWalkAnswersWhatItsProcedureDoes() async throws {
        // Given. `map` over strings with a procedure answering `Int`. What the
        // walk answers follows the procedure rather than the array it walks,
        // so asking for the array's type back is the disagreement
        let counting = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "item", type: .string)],
                returns: .int
            ),
            body: [],
            result: .call(Call(selector: "Standard.Collection.count", arguments: [reference("item")]))
        )
        let wants = Procedure(
            signature: Signature(parameters: [Parameter(name: "ns", type: .array(.string))]),
            body: []
        )
        let sut = try Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "names", type: .array(.string))]
                    ),
                    body: [
                        Statement(binding: .constant("sizes"), expression: .call(Call(
                            selector: "Standard.Collection.map",
                            arguments: [reference("names"), .closure(counting)]
                        ))),
                        Statement(binding: .constant("asked"), expression: .call(Call(
                                selector: "wants",
                                arguments: [reference("sizes")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with ns, which holds Array<Int> where Array<String> is declared")
        }
    }

    @Test("a loop's result carries the body name it reads, nullable")
    func aLoopResultCarriesTheBodyNameItReads() async throws {
        // Given. A finished round's exit hands the result the body's own
        // declarations; the 0-round exit never bound them, and a name a scope
        // does not hold reads as null. So `kept` holds `Int?`, not an `Any` for
        // a name the entry never saw, and not a plain `Int` the 0-round run would
        // break
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [Statement(binding: .constant("tick"), expression: .literal(.int(7)))],
                result: reference("tick")
            )
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("kept"), expression: loop),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("kept")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(parameters: [Parameter(name: "text", type: .string)]),
                    body: []
                )
            ]
        )

        // When / Then. Refused as the nullable it is
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("holds Int?")
        }

        // And the 0-round run answers the null the reading admitted
        let running = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("kept"), expression: .loop(
                                while: .literal(.bool(false)),
                                body: Block(
                                    body: [
                                        Statement(binding: .constant("tick"), expression: .literal(.int(7)))
                                    ],
                                    result: reference("tick")
                                )
                            )
                        )
                    ],
                    result: reference("kept")
                )
            ]
        )

        #expect(try await run([running]) == .null)
    }

    @Test("a name bound to a call carries that call's declared answer")
    func boundCallCarriesItsAnswer() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "counts": Procedure(
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1)))
                    ],
                    result: .reference([.key("done")])
                ),
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "counts"))),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("many")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds Int where String is declared")
        }
    }

    @Test("a field of a declared type carries the field's type")
    func declaredTypeCarriesItsFields() async throws {
        // Given
        let sut = try Module(
            types: [
                "Task": .record([
                        "done": .bool,
                        "id": .string
                    ])
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .named("Task"))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("task"), .key("done")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then. `task.done` is a bool, and the walk read that from the
        // type rather than from the value
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds Bool where String is declared")
        }
    }

    @Test("an element read by index carries the material's element type")
    func walkElementIsTyped() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "counts", type: .array(.int))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("walk"), expression: walking(
                                [.key("counts")],
                                element: "element",
                                body: [
                                    Statement(binding: .constant("said"), expression: .call(Call(
                                        selector: "wants",
                                        arguments: [reference("element")]
                                    )))
                                ]
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds Int where String is declared")
        }
    }

    @Test("a name a conditional may have rewritten holds neither reading")
    func disagreeingWritesAreUnknown() async throws {
        // Given. A join that guessed would be a refusal an author cannot act
        // on, so where two readings disagree nothing is claimed: the name
        // reads `Any`, which a slot of a type takes only through a cast
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "flag", type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.int(1))),
                        Statement(
                            expression: .conditional(equals(
                                        .reference([.key("flag")]),
                                        .literal(.bool(true))
                                        ), then: [
                                        Statement(binding: .assignment([.key("held")]), expression: .literal(.string("text")))
                                    ], else: nil)
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("held")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("holds Any where String is declared")
        }
    }

    @Test("a declared answer the body's answer fits builds")
    func agreeingTypesBuild() async throws {
        // Given. `counts` declares an `Int` and answers one
        let sut = try Module(
            procedures: [
                "counts": Procedure(
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1)))
                    ],
                    result: .reference([.key("done")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "names", type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "counts"))),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("many")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "number", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("what a map answers is typed by the closure it was given")
    func aMapAnswerCarriesItsElementType() async throws {
        // Given. `map` declares its answer through type parameters: the
        // closure's declared answer fills `Answer`, so handing the fan-out's
        // answer to a procedure that wants another type is refused before anything
        // runs
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("kept"), expression: .call(
                                Call(
                                    selector: "Standard.Concurrent.map",
                                    arguments: [
                                        .literal(.array([.int(1), .int(2)])),
                                        .closure(
                                            Procedure(
                                                signature: Signature(
                                                    parameters: [
                                                        Parameter(name: "item", type: .int),
                                                        Parameter(name: "index", type: .int)
                                                    ],
                                                    returns: .int
                                                ),
                                                body: [],
                                                result: reference("item")
                                            )
                                        )
                                    ]
                                )
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(
                            Call(selector: "wants", arguments: [reference("kept")])
                        ))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "names", type: .array(.string))]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("with names, which holds Array<Int> where Array<String> is declared")
        }
    }

    @Test("a write only one arm makes reads back nullable")
    func aWriteOnlyOneArmMakesReadsBackNullable() async throws {
        // Given. The run either took the arm or did not, so the name holds the
        // write or the null it started with: `T?`, and a slot that wants the
        // value plain refuses
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ready", type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("many"), expression: .literal(.null)),
                        Statement(
                            expression: .conditional(
                                .reference([.key("ready")]),
                                then: [
                                    Statement(binding: .assignment([.key("many")]), expression: .literal(.string("no")))
                                ],
                                else: nil
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("many")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds String? where String is declared")
        }
    }

    @Test("a path drilling a field into a type that has none is refused")
    func drillingIntoATypeWithoutFieldsIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "count", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("count"), .key("nope")]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("count.nope names 'nope', and Int has no name there to read")
        }
    }

    @Test("a path indexing into something that is not an array is refused")
    func indexingIntoANonArrayIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "name", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("name"), .index(0)]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("name[0] indexes into String, and an array is indexed by a position")
        }
    }

    @Test("a call on the type it reached is not refused")
    func aProcedureCalledOnAReadingIsAllowed() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "names", type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            binding: .constant("said"),
                            expression: .call(Call(selector: "Standard.Collection.count", arguments: [reference("names")]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a dot on any is refused, because any declares nothing to read")
    func aDotOnAnyIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("payload"), .key("whatever")]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("declares nothing")
        }
    }

    @Test("a cast naming a type nothing declares refuses at the build")
    func aCastNamingNothingIsRefused() async throws {
        // Given. `as?` says the author expected the value might not be that
        // type. A name nothing declares is not that, and letting it reach the
        // run would have `as?` read a typo as null forever. A type spelled in a
        // body is held to the rule a type spelled in a signature is
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [],
                    result: .cast(
                        .reference([.key("payload")]),
                        as: .named("Preson"),
                        optional: true
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no module in this link declares")
        }
    }

    @Test("a cast onto a type that proves nothing is refused, whatever it reads")
    func aCastOntoNothingIsRefused() async throws {
        // Given. The claim is judged on itself: `as: Any` opens no door over an
        // `Any` operand any more than it does over an `Int` one
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .any,
                                optional: false
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("`Any` is the absence of one")
        }
    }

    @Test("a cast to a record of other fields is refused, since a record is exactly its fields")
    func aCastOntoADisjointRecordIsRefused() async throws {
        // Given. A record type says all there is, so no value is a record of
        // these fields and of those at once
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "failed", type: .record(["type": .string, "message": .string]))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("reason"), expression: .cast(
                                .reference([.key("failed")]),
                                as: .record(["failures": .dictionary(.string)]),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("reason"), .key("failures")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is both")
        }
    }

    @Test("a cast between two types that name themselves does not chase them forever")
    func aCastBetweenRecursiveTypesTerminates() async throws {
        // Given. The reading is a declared type rather than `Any`, so the walk
        // actually asks whether both could hold. Both sides name themselves,
        // which is the case a guard living inside one expansion could not bound
        let sut = try Module(
            types: ["Tree": .record(["value": .int, "children": .array(.named("Tree"))])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .named("Tree"))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("tree"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .named("Tree"),
                                optional: true
                            )
                        )
                    ],
                    result: .reference([.key("tree"), .key("value")])
                )
            ]
        )

        // When / Then. The walk ends, and what it answers is that the reading
        // already is the type
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which it already is")
        }
    }

    @Test("a cast whose outer type cannot match is refused even where the inside is unproven")
    func aCastOntoAMismatchedKindIsRefusedThroughUnprovenInsides() async throws {
        // Given. `Array<Any>` proves an array is there. Nothing it holds is
        // proven, but that says nothing about whether the whole could be a
        // string, and it cannot: this would answer null on every run
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "rows", type: .array(.any))
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("rows")]), as: .string, optional: true)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is both")
        }
    }

    @Test("repeating a cast is refused whichever way the type was spelled")
    func aRepeatedCastIsRefusedInlineToo() async throws {
        // Given. `payload as? Int` hands on `Int?`, and the sameness question is
        // asked of what was handed on, so the repeat is refused however the
        // type is spelled
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("once"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .int,
                                optional: true
                            )
                        ),
                        Statement(binding: .constant("twice"), expression: .cast(
                                .reference([.key("once")]),
                                as: .int,
                                optional: true
                            )
                        )
                    ],
                    result: .reference([.key("twice")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("already is")
        }
    }

    @Test("a cast onto never in code nothing reaches is still refused")
    func anUnreadableClaimIsRefusedWhereNoWalkGoes() async throws {
        // Given. It runs, and nothing reaches it, so no typing walk sees it. What the
        // claim names is a fact about the spelling, so it is held anyway; `as?:
        // never` slipping through here would answer null forever
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.int(0))),
                "stranded": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [],
                    result: .cast(
                        .reference([.key("payload")]),
                        as: .never,
                        optional: true
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is")
        }
    }

    @Test("a name standing for a nullable is not wrapped again")
    func anAskingCastOntoANullableNameDoesNotDouble() async throws {
        // Given. `Maybe` already holds null, so `as?: Maybe` reads `Maybe`, the
        // same type whether the author wrote the name or what it stands for
        let sut = try Module(
            types: ["Maybe": .nullable(.int)],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("once"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .named("Maybe"),
                                optional: true
                            )
                        ),
                        Statement(binding: .constant("twice"), expression: .cast(
                                .reference([.key("once")]),
                                as: .named("Maybe"),
                                optional: true
                            )
                        )
                    ],
                    result: .reference([.key("twice")])
                )
            ]
        )

        // When / Then. The second says nothing the first did not
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("already is")
        }
    }

    @Test("a cast in a procedure nothing reaches still names a declared type")
    func aCastInUnreachedNonConstCodeIsStillHeldToItsName() async throws {
        // Given. It runs, and nothing reaches it from the entry, so neither the frontier
        // nor the const set walks it. A signature written here would still be
        // held to its names; so is a cast
        let sut = try Module(
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.int(0))),
                "stranded": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [],
                    result: .cast(
                        .reference([.key("payload")]),
                        as: .named("Preson"),
                        optional: true
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no module in this link declares")
        }
    }

    @Test("an Int never becomes a Double, so a cast onto Double refuses")
    func aCastOntoDoubleRefuses() async throws {
        // Given. A value is fixed at the build to the type it is read as, and
        // no value is both a whole number and a fraction
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "count", type: .int)
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("count")]), as: .double, optional: false)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("reads Int as Double, and no value is both")
        }
    }

    @Test("a nullable and null share null, so a cast between them stands")
    func aCastBetweenANullableAndNullStands() async throws {
        // Given. Asked of the fact that both hold null, not of which one is
        // written with `?`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "count", type: .nullable(.int))
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("count")]), as: .null, optional: true)
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("two nullables share null, so a cast between them stands")
    func aCastBetweenNullablesStands() async throws {
        // Given. Null satisfies both, so a value both types hold exists
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "count", type: .nullable(.int))
                        ]
                    ),
                    body: [],
                    result: .cast(
                        .reference([.key("count")]),
                        as: .nullable(.string),
                        optional: true
                    )
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a dictionary and a record are one value read two ways, so a cast between them stands")
    func aCastBetweenADictionaryAndARecordStands() async throws {
        // Given. A map holding exactly the record's fields is a value of
        // both, so refusing this would refuse a cast that succeeds
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .dictionary(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .record(["a": .string]),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("read"), .key("a")])
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("the reading a cast hands on is the name the author wrote")
    func aCastHandsOnItsName() async throws {
        // Given. Casting the result to the same declared name again is the
        // sameness rule's case, and it can only see that if the reading it was
        // handed is still `Person` rather than the type Person stands for.
        // (What a refusal *quotes* is the path walk's own business: it resolves
        // names at every step, for a cast's reading and a declared parameter's
        // alike.)
        let sut = try Module(
            types: ["Person": .record(["name": .string])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .named("Person"),
                                optional: false
                            )
                        ),
                        Statement(binding: .constant("again"), expression: .cast(
                                .reference([.key("read")]),
                                as: .named("Person"),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("again"), .key("name")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("already is")
        }
    }

    @Test("a cast between types no value is both is refused")
    func aCastThatCanNeverHoldIsRefused() async throws {
        // Given. The reading proves a string is there, and no string is a whole
        // number. `as?` here would answer null on every run, which is the
        // permanent silent null `as?` exists not to be
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("text")]), as: .int, optional: true)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is both")
        }
    }

    @Test("naming a step of a path through a parameter does not change what it means")
    func aParameterPathSurvivesBeingNamed() async throws {
        // Given. `of.a.b` in one statement stands, so `x = of.a` then `x.b`
        // must stand too. Folding the parameter walk's reading to `Any` made
        // the second refuse on a type the author never wrote
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .parameter(name: "T"))],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("held"), expression: .reference([.key("of"), .key("a")]))
                    ],
                    result: .reference([.key("held"), .key("b")])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        selector: "peek",
                        arguments: [.record(["a": .record(["b": .literal(.string("deep"))])])]
                    ))
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .string("deep"))
    }

    @Test("a constant folded before any run may hold a cast")
    func aConstantMayHoldACast() async throws {
        // Given. The build calls a cast const, so the const evaluator has to be
        // able to read one. A module constant is folded through that evaluator
        // before anything runs, so a cast in one is where the two would
        // disagree if only the build believed it
        let sut = try Module(
            constants: [
                "counted": .cast(
                    .literal(.int(7)),
                    as: .nullable(.int),
                    optional: true
                )
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .nullable(.int)),
                    body: [],
                    result: .reference([.key("counted")])
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(7))
    }

    @Test("a cast onto a type holding any opens the door it names, and no further")
    func aCastOntoATypeHoldingAnyOpensItsOwnDoor() async throws {
        // Given. `as: Array<Any>` is not `as: Any`: the types then prove an
        // array is there and an index reads one. What each element holds is
        // still nothing, so a dot on one is still refused. The door it named
        // opened, and only that one
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("rows"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .array(.any),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("rows"), .index(0)])
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a cast is not called needless where what it reads holds any inside")
    func aCastIntoAnUnprovenFieldStands() async throws {
        // Given. The reading proves a record is there and proves nothing about
        // `data`. Calling this cast needless would refuse the author both ways:
        // the cast as saying nothing, and the dot it would have allowed as
        // unjudgeable
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .record(["data": .any]))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .record(["data": .record(["name": .string])]),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("read"), .key("data"), .key("name")])
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a cast keeps the name the author wrote, not the type it stands for")
    func aCastKeepsItsName() async throws {
        // Given. The build walks a declared name through to judge it, and what
        // it writes back is what was written: a refusal and a document both
        // read the author's spelling
        let sut = try Module(
            types: ["Person": .record(["name": .string])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .named("Person"),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("read"), .key("name")])
                )
            ]
        )

        // When
        let image = try await builder.build([sut] + Module.standard)

        // Then
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            let read = body.instructions.first(where: { instruction in instruction.label == "read" }),
            case let .cast(_, type, _) = read.code
        else {
            Issue.record("the cast did not survive the build")

            return
        }

        #expect(type.rendered(in: image.loweredTypes).contains("Person"))
    }

    @Test("a cast opens what any declares nothing about")
    func aCastOpensAny() async throws {
        // Given. The same read, with the type the author expects named: the
        // dot is judged against that type, and the run is left only the
        // question of what arrived
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "payload", type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .record(["whatever": .string]),
                                optional: false
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .reference([.key("read"), .key("whatever")]))
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a field the record does not declare is refused, ?. or not")
    func anUndeclaredFieldIsRefused() async throws {
        // Given. The type proved the absence, so no spelling reads past it:
        // `?.` speaks about what may be absent at run, not about what the
        // declaration already decided
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .record(["id": .string]))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("task"), .key("done")]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }

        // The optional spelling changes nothing a declaration decided.
        let optional = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .record(["id": .string]))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("task"), .key("done", optional: true)]))
                    ]
                )
            ]
        )

        await #expect {
            try await builder.build([optional] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("a write a break carries out of the loop is still counted")
    func aWriteABreakCarriesOutIsCounted() async throws {
        // Given. The arm writes and then breaks: no run comes back to the arm,
        // but the loop absorbs the break and the flow after the loop goes on
        // with the write in the box. The write may be a null, so the name reads
        // back nullable and the plain slot refuses.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ready", type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))),
                        Statement(binding: .constant("spin"), expression: .loop(
                                while: .reference([.key("ready")]),
                                body: Block(body: [
                                    Statement(
                                        expression: .conditional(
                                            .reference([.key("ready")]),
                                            then: [
                                                Statement(binding: .assignment([.key("held")]), expression: .literal(.null)),
                                                Statement(
                                                    expression: .leave(
                                                        Leave(reach: .construct, target: nil, value: nil)
                                                    )
                                                )
                                            ],
                                            else: nil
                                        )
                                    )
                                ])
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("held")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds String? where String is declared")
        }
    }

    @Test("a rescue reads what the body may have written before it failed")
    func aRescueReadsTheBodysPartialWrites() async throws {
        // Given. The body writes a null and then risks a failing cast: the
        // rescue runs with that write in the box, so inside the rescue the name
        // reads `String?` and the plain `String` slot refuses.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))),
                        Statement(
                            expression: .attempt(
                                Block(body: [
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.null)),
                                    mayFail("risky")
                                ]),
                                rescue: Block(body: [
                                    Statement(binding: .constant("saidInside"), expression: .call(Call(
                                        selector: "wants",
                                        arguments: [.reference([.key("held")])]
                                    )))
                                ], result: .literal(.string("rescued")))
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("with text, which holds String? where String is declared")
        }
    }

    @Test("a round reads what its own earlier rounds may have written")
    func aRoundReadsItsEarlierRoundsWrites() async throws {
        // Given. The first round reads the seed, but the body also writes a
        // null, and every later round reads that: inside the loop the name
        // reads `String?`, so the plain `String` slot refuses.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ready", type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))),
                        Statement(binding: .constant("spin"), expression: .loop(
                                while: .reference([.key("ready")]),
                                body: Block(body: [
                                    Statement(binding: .constant("said"), expression: .call(Call(
                                        selector: "wants",
                                        arguments: [.reference([.key("held")])]
                                    ))),
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.null))
                                ])
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds String? where String is declared")
        }
    }

    @Test("a chain of writes converges link by link, however long")
    func aChainOfWritesConverges() async throws {
        // Given. Each round moves the null one link up the chain, so the head
        // only reads nullable after as many looks as the chain is long.
        let names: [Name] = ["a", "b", "c", "d", "e", "f"]
        let chain = Body(zip(names, names.dropFirst()).map { name, next in
            Statement(binding: .assignment([.key(name)]), expression: .reference([.key(next)]))
        } + [Statement(binding: .assignment([.key("f")]), expression: .literal(.null))])

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ready", type: .bool)
                        ]
                    ),
                    body: Body(names.map { name in
                        Statement(binding: .variable(name), expression: .literal(.string("s")))
                    } + [
                        Statement(binding: .constant("spin"), expression: .loop(
                                while: .reference([.key("ready")]),
                                body: Block(body: chain)
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("a")])]
                        )))
                    ])
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then. `a` reads `String?` after enough rounds
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds String? where String is declared")
        }
    }

    @Test("a rescue's write is counted even when the body always leaves")
    func aRescueWriteSurvivesALeavingBody() async throws {
        // Given. The rescue runs on the world failing, which no reading of the
        // body's leaves rules out: a body that always returns can still fail
        // before its return, and what the rescue wrote is then in the box. The
        // write may be a null, so the name reads back nullable and the plain
        // slot refuses.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))),
                        Statement(
                            expression: .attempt(
                                Block(body: [
                                    mayFail("risky"),
                                    Statement(
                                        expression: .leave(Leave(reach: .procedure, value: nil))
                                    )
                                ]),
                                rescue: Block(body: [
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.null))
                                ], result: .literal(.string("rescued")))
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.literal(.string("hey")), .reference([.key("held")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .string),
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then. `held` reads `String?`, and the plain `String` slot says
        // so
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("with text, which holds String? where String is declared")
        }
    }

    @Test("what the body may have written is not overwritten by the rescue's write")
    func aBodyWriteJoinsTheRescueWrite() async throws {
        // Given. The body wrote a String or got nowhere, the rescue wrote an
        // Int or never ran: the name holds any of null, the String and the
        // Int. That is `Any` (where readings disagree the slot holds neither),
        // which the String slot below takes only through a cast. A rescue that
        // overwrote the body's write would read `Int` instead.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.null)),
                        Statement(
                            expression: .attempt(
                                Block(body: [
                                    mayFail(),
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.string("text")))
                                ]),
                                rescue: Block(body: [
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.int(1)))
                                ], result: .literal(.string("rescued")))
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("held")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("with text, which holds Any where String is declared")
        }
    }

    @Test("an arm that refuses does not cost the arm that writes its say")
    func refusingArmKeepsTheOtherArmsType() async throws {
        // Given. No run comes back from the refusing arm, so the ways that
        // finish all made the other arm's write: the name reads as that write
        // alone, not as a maybe
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ready", type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("many"), expression: .literal(.null)),
                        Statement(
                            expression: .conditional(
                                .reference([.key("ready")]),
                                then: [
                                    Statement(binding: .assignment([.key("many")]), expression: .literal(.int(1)))
                                ],
                                else: [Statement(expression: aborting(literal("no")))]
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("many")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with text, which holds Int where String is declared")
        }
    }

    @Test("an attempt whose body only refuses holds what the rescue answers")
    func attemptHoldsTheRescueWhenTheBodyRefuses() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .attempt(
                                Block(body: [], result: aborting(literal("no"))),
                                rescue: Block(body: [], result: .literal(.string("fallback")))
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("many")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "number", type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'wants' with number, which holds String where Int is declared")
        }
    }

    @Test("a name on a call that never finishes is refused at the build")
    func refusingBodySaysNothingAboutItsAnswer() async throws {
        // Given. `gives_up` declares `Never`, so a name on its call promises a
        // binding that cannot happen. The build refuses the name where the
        // signature is known, rather than inventing a type for the binding
        let sut = try Module(
            procedures: [
                "gives_up": Procedure(
                    signature: Signature(
                        returns: .never
                    ),
                    body: [
                        Statement(binding: .constant("no"), expression: aborting(literal("no")))
                    ]
                ),
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "gives_up"))),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("many")])]
                        )))
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "text", type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("never finishes")
        }
    }

    @Test("a dot on a record is a read, and a procedure there is written as a call")
    func aDotOnARecordDoesNotReachAProcedure() async throws {
        // Given. The record does not declare the name, and a type with fields
        // reads fields alone: the procedure by that name is not consulted, and the
        // refusal says to write the call
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("task"), expression: .record(["id": .literal(.string("a"))]))
                    ],
                    result: .reference([.key("task"), .key("absolute")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("does not declare")
                && "\(error)".contains("A procedure is sent with a written call")
        }
    }

    @Test("a dot on a type with no fields says to write the call")
    func aDotOnAFieldlessTypeSaysToWriteTheCall() async throws {
        // Given. Text has no name to read, so the refusal names the one
        // spelling that reaches the procedure: the written call
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("task"), expression: .literal(.string("a")))
                    ],
                    result: .reference([.key("task"), .key("count")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("String has no name there to read")
                && "\(error)".contains("sent with a written call")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

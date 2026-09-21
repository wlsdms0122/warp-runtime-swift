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

// An author binds a call to a name and passes the name, so a declared answer
// only reaches the next call site if the build knows what that name holds. These
// are the places knowing it turns two declarations into a refusal before
// anything runs.
@Suite("What the build knows a name holds")
struct InferenceTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a type parameter carries the element type through the call that filled it")
    func aHoleCarriesWhatFilledIt() async throws {
        // Given. `first` takes `array<some Element>` and answers `some
        // Element`, so what it answers here is a string and the declaration
        // never said so
        let wants = Procedure(
            signature: Signature(parameters: ["procedure": Parameter(type: .string)]),
            body: []
        )
        let sut = try Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [
                        Statement(binding: .constant("head"), expression: .call(Call(
                                receiver: reference("names"),
                                selector: "std.collection.first"
                            ))
                        ),
                        Statement(binding: .constant("asked"), expression: .call(Call(
                                selector: "wants",
                                arguments: ["procedure": reference("head")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a type parameter filled with one type refuses a call wanting another")
    func aFilledHoleRefusesWhatDisagrees() async throws {
        // Given. The same walk, over an array of ints
        let wants = Procedure(
            signature: Signature(parameters: ["procedure": Parameter(type: .string)]),
            body: []
        )
        let sut = try Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: ["counts": Parameter(type: .array(.int))]
                    ),
                    body: [
                        Statement(binding: .constant("head"), expression: .call(Call(
                                receiver: reference("counts"),
                                selector: "std.collection.first"
                            ))
                        ),
                        Statement(binding: .constant("asked"), expression: .call(Call(
                                selector: "wants",
                                arguments: ["procedure": reference("head")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a type parameter a procedure answers becomes what the walk answers")
    func aWalkAnswersWhatItsProcedureDoes() async throws {
        // Given. `map` over strings with a procedure answering int. What the
        // walk answers follows the procedure rather than the receiver, so
        // asking for the receiver's type back is the disagreement
        let counting = Procedure(
            signature: Signature(
                parameters: ["item": Parameter(type: .string)],
                returns: .int
            ),
            body: [],
            result: .call(Call(receiver: reference("item"), selector: "std.collection.count"))
        )
        let wants = Procedure(
            signature: Signature(parameters: ["ns": Parameter(type: .array(.string))]),
            body: []
        )
        let sut = try Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [
                        Statement(binding: .constant("sizes"), expression: .call(Call(
                                receiver: reference("names"),
                                selector: "std.collection.map",
                                arguments: ["value": .closure(counting)]
                            ))
                        ),
                        Statement(binding: .constant("asked"), expression: .call(Call(
                                selector: "wants",
                                arguments: ["ns": reference("sizes")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    // MARK: - Test
    @Test("a loop's result carries the body name it reads, nullable")
    func aLoopResultCarriesTheBodyNameItReads() async throws {
        // Given. A finished round's exit hands the result the body's own
        // declarations; the 0-round exit never bound them, and a name a scope
        // does not hold reads as null. So `kept` holds int?, not an `any` for
        // a name the entry never saw, and not a plain int the 0-round run would
        // break
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [Statement(binding: .constant("tick"), expression: .literal(.int(7)))],
                result: reference("tick")
            ),
            round: "walked"
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("kept"), expression: loop),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                "procedure": .reference([.key("kept")])
                            ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(parameters: ["procedure": Parameter(type: .string)]),
                    body: []
                )
            ]
        )

        // When / Then. Refused as the nullable it is
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("holds int?")
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
                                ),
                                round: "walked"
                            )
                        )
                    ],
                    result: reference("kept")
                )
            ]
        )

        #expect(try await run([running]) == .null)
    }

    @Test("a loop result's writes stay out of the rounds' own reading")
    func aLoopResultsWritesStayOutOfTheRounds() async throws {
        // Given. The result runs once, at an exit, never between rounds; a body
        // that reads `y` as the int it is must not be refused on account of a
        // write only the exit makes
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [
                    Statement(binding: .constant("used"), expression: .call(Call(selector: "wants", arguments: [
                            "count": .reference([.key("y")])
                        ]))
                    )
                ],
                result: .block(
                    Block(
                        body: [
                            Statement(binding: .assignment([.key("y")]), expression: .literal(.string("s"))
                            )
                        ],
                        result: reference("y")
                    )
                )
            ),
            round: "walked"
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("y"), expression: .literal(.int(1))),
                        Statement(binding: .constant("kept"), expression: loop)
                    ],
                    result: reference("y")
                ),
                "wants": Procedure(
                    signature: Signature(parameters: ["count": Parameter(type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then. Links, and the run answers what the exit wrote
        #expect(try await run([sut]) == .string("s"))
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
                        Statement(binding: .constant("done"), expression: .literal(.int(1))
                        )
                    ],
                    result: .reference([.key("done")])
                ),
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "counts"))
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
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
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "task": Parameter(type: .named("Task"))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("task"), .key("done")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then. `task.done` is a bool, and the walk read that from the
        // type rather than from the value
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a path that ends in a procedure carries what the procedure answers")
    func pathProcedureCarriesItsAnswer() async throws {
        // Given. `${names.count}` is `count` sent to `names`, and `count`
        // declares that it answers an int
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("names"), .key("count")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("an element read by index carries the material's element type")
    func walkElementIsTyped() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "counts": Parameter(type: .array(.int))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("walk"), expression: walking(
                                [.key("counts")],
                                element: "element",
                                body: [
                                    Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                                    "procedure": reference("element")
                                                ]))
                                    )
                                ]
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a name a conditional may have rewritten holds neither reading")
    func disagreeingWritesAreUnknown() async throws {
        // Given. A join that guessed would be a refusal an author cannot act
        // on, so where two readings disagree nothing is claimed
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "flag": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.int(1))
                        ),
                        Statement(
                            expression: .conditional(equals(
                                        .reference([.key("flag")]),
                                        .literal(.bool(true))
                                        ), then: [
                                        Statement(binding: .assignment([.key("held")]), expression: .literal(.string("text"))
                                        )
                                    ], else: nil)
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a declared answer is checked against what the body actually names")
    func rightTypesLink() async throws {
        // Given. The same types, agreeing
        let sut = try Module(
            procedures: [
                "counts": Procedure(
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1))
                        )
                    ],
                    result: .reference([.key("done")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "counts"))
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("what a map answers is typed by the closure it was given")
    func aMapAnswerCarriesItsElementType() async throws {
        // Given. `map` declares its answer through type parameters: the
        // closure's declared answer fills `Answer`, so handing the fan-out's
        // answer to a procedure that wants another kind is refused before anything
        // runs
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("kept"), expression: .call(
                                Call(
                                    receiver: .literal(.array([.int(1), .int(2)])),
                                    selector: "std.concurrent.map",
                                    arguments: [
                                        "by": .closure(
                                            Procedure(
                                                signature: Signature(
                                                    parameters: ["item": Parameter(type: .int)],
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
                                Call(
                                    selector: "wants",
                                    arguments: ["procedures": reference("kept")]
                                )
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: ["procedures": Parameter(type: .array(.string))]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a write only one arm makes reads back nullable")
    func aWriteOnlyOneArmMakesReadsBackNullable() async throws {
        // Given. The run either took the arm or did not, so the name holds the
        // write or the null it started with: `T?`, and a slot that wants the
        // value plain refuses
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("many"), expression: .literal(.null)
                        ),
                        Statement(
                            expression: .conditional(
                                .reference([.key("ready")]),
                                then: [
                                    Statement(binding: .assignment([.key("many")]), expression: .literal(.string("no"))
                                    )
                                ],
                                else: nil
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a path drilling a field into a type that has none is refused")
    func drillingIntoATypeWithoutFieldsIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("count"), .key("nope")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a path indexing into something that is not an array is refused")
    func indexingIntoANonArrayIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "name": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("name"), .index(0)])
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a call on the type it reached is not refused")
    func aProcedureCalledOnAReadingIsAllowed() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            binding: .constant("said"),
                            expression: .call(Call(receiver: reference("names"), selector: "std.collection.count"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a dot on any is refused, because any declares nothing to read")
    func aDotOnAnyIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("payload"), .key("whatever")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
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
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("no module in this link declares")
        }
    }

    @Test("a cast onto a type that proves nothing is refused, whatever it reads")
    func aCastOntoNothingIsRefused() async throws {
        // Given. The claim is judged on itself: `as: any` opens no door over an
        // `any` receiver any more than it does over an `int` one
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("`any` is the absence of one")
        }
    }

    @Test("a cast may name a type sharing no field with the reading")
    func aCastOntoADisjointRecordStands() async throws {
        // Given. Two records naming no field in common accept each other in
        // neither direction and are still both satisfied by one value: a record
        // says what must be there, not all there is. This is the spelling the
        // specification gives for reading what a failure carries
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "failed": Parameter(type: .record(["type": .string, "message": .string]))
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
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a cast between two types that name themselves does not chase them forever")
    func aCastBetweenRecursiveTypesTerminates() async throws {
        // Given. The reading is a declared type rather than `any`, so the walk
        // actually asks whether both could hold. Both sides name themselves,
        // which is the case a guard living inside one expansion could not bound
        let sut = try Module(
            types: ["Tree": .record(["value": .int, "children": .array(.named("Tree"))])],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .named("Tree"))
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

        // When / Then. It terminates; whether it refuses as needless is the
        // sameness rule's business, not this one's
        _ = try? await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a cast whose outer kind cannot match is refused even where the inside is unproven")
    func aCastOntoAMismatchedKindIsRefusedThroughUnprovenInsides() async throws {
        // Given. `array<any>` proves an array is there. Nothing it holds is
        // proven, but that says nothing about whether the whole could be a
        // string, and it cannot: this would answer null on every run
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "rows": Parameter(type: .array(.any))
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("rows")]), as: .string, optional: true)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is both")
        }
    }

    @Test("repeating a cast is refused whichever way the type was spelled")
    func aRepeatedCastIsRefusedInlineToo() async throws {
        // Given. `payload as? int` hands on `int?`, and asking the sameness
        // question of the spelling rather than of what was handed on let this
        // repeat through while the same repeat written with a name was caught
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("already is")
        }
    }

    @Test("a cast onto any in code nothing reaches is still refused")
    func anUnreadableClaimIsRefusedWhereNoWalkGoes() async throws {
        // Given. It runs, and nothing reaches it, so no typing walk sees it. What the
        // claim names is a fact about the spelling, so it is held anyway; `as?:
        // never` slipping through here would answer null forever
        let sut = try Module(
            procedures: [
                "entry": Procedure(access: .public, body: [], result: .literal(.int(0))),
                "stranded": Procedure(
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is")
        }
    }

    @Test("a name standing for a nullable is not wrapped again")
    func anAskingCastOntoANullableNameDoesNotDouble() async throws {
        // Given. `Maybe` already holds null, so `as?: Maybe` reads `Maybe`.
        // Wrapping the name again made the same type read two ways depending
        // on whether the author wrote the name or what it stands for, and the
        // second cast then escaped the sameness rule
        let sut = try Module(
            types: ["Maybe": .nullable(.int)],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
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
                "entry": Procedure(access: .public, body: [], result: .literal(.int(0))),
                "stranded": Procedure(
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("no module in this link declares")
        }
    }

    @Test("an int may become a double, so a cast onto double stands")
    func aCastOntoDoubleStands() async throws {
        // Given. The one widening the language has. Refusing it at the build
        // would refuse a cast that settles on every run
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .int)
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("count")]), as: .double, optional: false)
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a nullable and null share null, so a cast between them stands")
    func aCastBetweenANullableAndNullStands() async throws {
        // Given. Asked of the fact that both hold null, not of which one is
        // written with `?`
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .nullable(.int))
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("count")]), as: .null, optional: true)
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("two nullables share null, so a cast between them stands")
    func aCastBetweenNullablesStands() async throws {
        // Given. Null satisfies both, so a value both types hold exists
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .nullable(.int))
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
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a dictionary and a record are one value read two ways, so a cast between them stands")
    func aCastBetweenADictionaryAndARecordStands() async throws {
        // Given. The boundary settles both from the same runtime value, so
        // refusing this would refuse a cast that succeeds
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .dictionary(.string))
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
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
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
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("already is")
        }
    }

    @Test("a cast onto a type that names itself does not chase the name forever")
    func aCastOntoARecursiveTypeTerminates() async throws {
        // Given. A type may name itself, and the build's own guarantee that name
        // chains are finite covers walks that follow names alone. This walk
        // goes into fields too, so it carries its own guard
        let sut = try Module(
            types: ["Tree": .record(["value": .int, "children": .array(.named("Tree"))])],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("tree"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .named("Tree"),
                                optional: false
                            )
                        )
                    ],
                    result: .reference([.key("tree"), .key("value")])
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a cast between types no value is both is refused")
    func aCastThatCanNeverHoldIsRefused() async throws {
        // Given. The reading proves a string is there, and no string is a whole
        // number. `as?` here would answer null on every run, which is the
        // permanent silent null `as?` exists not to be
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [],
                    result: .cast(.reference([.key("procedure")]), as: .int, optional: true)
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("no value is both")
        }
    }

    @Test("naming a step of a path through a parameter does not change what it means")
    func aParameterPathSurvivesBeingNamed() async throws {
        // Given. `of.a.b` in one statement stands, so `x = of.a` then `x.b`
        // must stand too. Folding the parameter walk's reading to `any` made
        // the second refuse on a type the author never wrote
        let sut = try Module(
            procedures: [
                "peek": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .parameter(name: "T"))],
                        returns: .any
                    ),
                    body: [
                        Statement(binding: .constant("held"), expression: .reference([.key("of"), .key("a")]))
                    ],
                    result: .reference([.key("held"), .key("b")])
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [],
                    result: .call(Call(
                        receiver: .record(["a": .record(["b": .literal(.string("deep"))])]),
                        selector: "peek",
                        arguments: [:]
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
                    as: .ranged(.whole(from: 0, to: .through(10))),
                    optional: true
                )
            ],
            procedures: [
                "entry": Procedure(
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
        // Given. `as: array<any>` is not `as: any`: the types then prove an
        // array is there and an index reads one. What each element holds is
        // still nothing, so a dot on one is still refused. The door it named
        // opened, and only that one
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a cast is not called needless where what it reads holds any inside")
    func aCastIntoAnUnprovenFieldStands() async throws {
        // Given. The reading proves a record is there and proves nothing about
        // `data`. Calling this cast needless would refuse the author both ways:
        // the cast as saying nothing, and the dot it would have allowed as
        // unjudgeable
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .record(["data": .any]))
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
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a cast keeps the name the author wrote, not the type it stands for")
    func aCastKeepsItsName() async throws {
        // Given. The build walks a declared name through to judge it, and what
        // it writes back is what was written: a refusal and a document both
        // read the author's spelling
        let sut = try Module(
            types: ["Person": .record(["name": .string])],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
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
        let image = try await builder.build([sut] + Module.standard, entry: entryName)

        // Then
        guard
            case let .body(body, _) = image.entry.implementation,
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
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .cast(
                                .reference([.key("payload")]),
                                as: .record(["whatever": .string]),
                                optional: false
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .reference([.key("read"), .key("whatever")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a field the record does not declare is refused, ?. or not")
    func anUndeclaredFieldIsRefused() async throws {
        // Given. The type proved the absence, so no spelling reads past it:
        // `?.` speaks about what may be absent at run, not about what the
        // declaration already settled
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "task": Parameter(type: .record(["id": .string]))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("task"), .key("done")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }

        // The optional spelling changes nothing a declaration settled.
        let optional = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "task": Parameter(type: .record(["id": .string]))
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("said"), expression: .reference([.key("task"), .key("done", optional: true)])
                        )
                    ]
                )
            ]
        )

        await #expect {
            try await builder.build([optional] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("a write a break carries out of the loop is still counted")
    func aWriteABreakCarriesOutIsCounted() async throws {
        // Given. The arm writes and then breaks: no run comes back to the arm,
        // but the loop absorbs the break and the flow after the loop goes on
        // with the write in the box. The write may be a null, so the name reads
        // back nullable and the plain slot refuses. A reading that dropped what
        // left with the break would have said `string` and linked a lie.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))
                        ),
                        Statement(binding: .constant("spin"), expression: .loop(
                                while: .reference([.key("ready")]),
                                body: Block(body: [
                                    Statement(
                                        expression: .conditional(
                                            .reference([.key("ready")]),
                                            then: [
                                                Statement(binding: .assignment([.key("held")]), expression: .literal(.null)
                                                ),
                                                Statement(
                                                    expression: .leave(
                                                        Leave(reach: .construct, target: nil, value: nil)
                                                    )
                                                )
                                            ],
                                            else: nil
                                        )
                                    )
                                ]),
                                round: "spin"
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a later field reads what an earlier field wrote")
    func aLaterFieldReadsAnEarlierFieldsWrite() async throws {
        // Given. Fields evaluate in name order, and that order is the same fact
        // for the run and for the reading: field `a` writes the variable, so
        // field `b` reads it as the int `a` left, not as the null the record
        // was entered with.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.null)
                        ),
                        Statement(binding: .constant("made"), expression: .record([
                                "a": .block(
                                    Block(
                                        body: [
                                            Statement(binding: .assignment([.key("held")]), expression: .literal(.int(1))
                                            )
                                        ],
                                        result: .literal(.int(0))
                                    )
                                ),
                                "b": .reference([.key("held")])
                            ])
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("made"), .key("b")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then. Links, because `b` is an int by the time it is read
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("a rescue reads what the body may have written before it failed")
    func aRescueReadsTheBodysPartialWrites() async throws {
        // Given. The body writes a null and then risks a failing call: the
        // rescue runs with that write in the box, so inside the rescue the name
        // reads `string?` and the plain string slot refuses. A rescue judged in
        // the entry environment would have linked a lie.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))
                        ),
                        Statement(
                            expression: .attempt(
                                Block(body: [
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.null)
                                    ),
                                    Statement(binding: .constant("risky"), expression: .call(Call(selector: "wants", arguments: [
                                                    "procedure": .literal(.string("x"))
                                                ]))
                                    )
                                ]),
                                rescue: Block(body: [
                                    Statement(binding: .constant("saidInside"), expression: .call(Call(selector: "wants", arguments: [
                                                    "procedure": .reference([.key("held")])
                                                ]))
                                    )
                                ], result: .literal(.string("rescued"))),
                                failure: "why"
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a round reads what its own earlier rounds may have written")
    func aRoundReadsItsEarlierRoundsWrites() async throws {
        // Given. The first round reads the seed, but the body also writes a
        // null, and every later round reads that: inside the loop the name
        // reads `string?`, so the plain string slot refuses. A body judged once
        // against the entry environment would have linked the first round and
        // lied about the rest.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))
                        ),
                        Statement(binding: .constant("spin"), expression: .loop(
                                while: .reference([.key("ready")]),
                                body: Block(body: [
                                    Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                                    "procedure": .reference([.key("held")])
                                                ]))
                                    ),
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.null)
                                    )
                                ]),
                                round: "spin"
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a chain of writes settles link by link, however long")
    func aChainOfWritesSettles() async throws {
        // Given. Each round moves the null one link up the chain, so the head
        // only reads nullable after as many settles as the chain is long. A
        // walk that stopped counting early would return the head still plain
        // and link a lie.
        let names: [Name] = ["a", "b", "c", "d", "e", "f"]
        let chain: [Statement] = zip(names, names.dropFirst()).map { name, next in
            Statement(binding: .assignment([.key(name)]), expression: .reference([.key(next)]))
        } + [Statement(binding: .assignment([.key("f")]), expression: .literal(.null))]

        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: names.map { name in
                        Statement(binding: .variable(name), expression: .literal(.string("s")))
                    } + [
                        Statement(binding: .constant("spin"), expression: .loop(
                                while: .reference([.key("ready")]),
                                body: Block(body: chain),
                                round: "spin"
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("a")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then. `a` reads `string?` after enough rounds
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
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
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.string("seed"))
                        ),
                        Statement(
                            expression: .attempt(
                                Block(body: [
                                    Statement(binding: .constant("risky"), expression: .call(
                                            Call(
                                                receiver: .literal(.string("hey")),
                                                selector: "wants",
                                                arguments: ["procedure": .literal(.string("x"))]
                                            )
                                        )
                                    ),
                                    Statement(
                                        expression: .leave(Leave(reach: .procedure, value: nil))
                                    )
                                ]),
                                rescue: Block(body: [
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.null)
                                    )
                                ], result: .literal(.string("rescued"))),
                                failure: "why"
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string),
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then. `held` reads `string?`, and the plain string slot says
        // so
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("what the body may have written is not overwritten by the rescue's write")
    func aBodyWriteJoinsTheRescueWrite() async throws {
        // Given. The body wrote a string or got nowhere, the rescue wrote an
        // int or never ran: the name holds any of null, the string and the int.
        // That is `any` (where readings disagree the slot holds neither) and
        // `any` passes the string slot below, where a join that kept only the
        // rescue's int would have refused it wrongly.
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.null)
                        ),
                        Statement(
                            expression: .attempt(
                                Block(body: [
                                    mayFail(),
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.string("text"))
                                    )
                                ]),
                                rescue: Block(body: [
                                    Statement(binding: .assignment([.key("held")]), expression: .literal(.int(1))
                                    )
                                ], result: .literal(.string("rescued"))),
                                failure: "why"
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("an arm that refuses does not cost the arm that writes its say")
    func refusingArmKeepsTheOtherArmsType() async throws {
        // Given. No run comes back from the refusing arm, so the ways that
        // finish all made the other arm's write: the name reads as that write
        // alone, not as a maybe
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(binding: .variable("many"), expression: .literal(.null)
                        ),
                        Statement(
                            expression: .conditional(
                                .reference([.key("ready")]),
                                then: [
                                    Statement(binding: .assignment([.key("many")]), expression: .literal(.int(1))
                                    )
                                ],
                                else: [Statement(expression: refusing(literal("no")))]
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("an attempt whose body only refuses holds what the rescue answers")
    func attemptHoldsTheRescueWhenTheBodyRefuses() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .attempt(
                                Block(body: [], result: refusing(literal("no"))),
                                rescue: Block(body: [], result: .literal(.string("fallback"))),
                                failure: "why"
                            )
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a name on a call that never finishes is refused at link")
    func refusingBodySaysNothingAboutItsAnswer() async throws {
        // Given. `gives_up` declares never, so a name on its call promises a
        // binding that cannot happen. The build refuses the name where the
        // signature is known, rather than inventing a type for the binding
        let sut = try Module(
            procedures: [
                "gives_up": Procedure(
                    signature: Signature(
                        returns: .never
                    ),
                    body: [
                        Statement(binding: .constant("no"), expression: refusing(literal("no"))
                        )
                    ]
                ),
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("many"), expression: .call(Call(selector: "gives_up"))
                        ),
                        Statement(binding: .constant("said"), expression: .call(Call(selector: "wants", arguments: [
                                        "procedure": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "procedure": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("never finishes")
        }
    }
}

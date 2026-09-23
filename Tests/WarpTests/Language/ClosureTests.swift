//
//  ClosureTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// A procedure is a value. What that buys is not the case list. It is that an
// author can write the two things only Swift could write before: a construct
// that takes a body, and a procedure that makes one.
@Suite("A procedure is a value")
struct ClosureTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a closure captures the scope it was written in, not the one it runs in")
    func closureCapturesLexically() async throws {
        // Given. `made` is written where `outer` says "written"; the call site
        // has an `outer` of its own saying something else
        let sut = [
            Statement(binding: .constant("outer"), expression: .literal(.string("written"))),
            Statement(binding: .constant("made"), expression: .closure(Procedure(body: [], result: reference("outer")))
            )
        ]

        // When
        let answer = try await answer(
            of: sut + [
                Statement(binding: .constant("shadow"), expression: .literal(.string("called"))),
                Statement(binding: .constant("said"), expression: .apply(reference("made"), arguments: [:])
                )
            ],
            result: reference("said")
        )

        // Then
        #expect(answer == .string("written"))
    }

    @Test("a body declares every name the slot hands and no other", arguments: [
        (["item": Parameter(type: .int)] as [Name: Parameter], true),
        ([:], false),
        (["item": Parameter(type: .int), "index": Parameter(type: .int)], false)
    ])
    func aBodyDeclaresWhatTheSlotHandsIt(declared: [Name: Parameter], fits: Bool) async throws {
        // Given. The slot hands one name. A body declaring it stands; one
        // declaring none is handed a name it does not have, and one writing a
        // name nothing hands it could only ever read null there.
        let walking = Procedure(
            signature: Signature(
                parameters: [
                    "by": Parameter(
                        type: .procedure(Signature(parameters: ["item": Parameter(type: .int)]))
                    )
                ]
            ),
            body: [
                Statement(
                    binding: .constant("once"),
                    expression: .apply(reference("by"), arguments: ["item": .literal(.int(1))])
                )
            ]
        )
        let sut = try Module(
            procedures: [
                "walking": walking,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("body"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(parameters: declared),
                                    body: [],
                                    result: .literal(.int(1))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("ran"),
                            expression: .call(Call(
                                selector: "walking",
                                arguments: ["by": reference("body")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        if fits {
            await #expect(throws: Never.self) {
                try await Builder().build([sut] + Module.standard)
            }
        } else {
            await #expect(throws: BuildError.self) {
                try await Builder().build([sut] + Module.standard)
            }
        }
    }

    @Test("an extra name a call need not fill is a name the body may declare")
    func anExtraParameterThatStandsUnfilledFits() async throws {
        // Given. The slot hands one name and the body writes two, the second
        // with a default. Nothing has to fill it, so the body reads what it
        // declared rather than the null the width rule refuses.
        let walking = Procedure(
            signature: Signature(
                parameters: [
                    "by": Parameter(
                        type: .procedure(Signature(parameters: ["item": Parameter(type: .int)]))
                    )
                ]
            ),
            body: [
                Statement(
                    binding: .constant("once"),
                    expression: .apply(reference("by"), arguments: ["item": .literal(.int(1))])
                )
            ]
        )
        let sut = try Module(
            procedures: [
                "walking": walking,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("body"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(parameters: [
                                        "item": Parameter(type: .int),
                                        "index": Parameter(type: .int, default: .int(0))
                                    ]),
                                    body: [],
                                    result: .literal(.int(1))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("ran"),
                            expression: .call(Call(
                                selector: "walking",
                                arguments: ["by": reference("body")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a slot asking for a const procedure refuses one that reaches outside")
    func aClosureThatRunsIsRefusedWhereConstIsAsked() async throws {
        // Given. `twice` declares that whatever it is handed answers without
        // running. The closure handed to it shouts, and shouting is an effect
        let twice = Procedure(
            signature: Signature(
                parameters: ["body": Parameter(type: .procedure(nil, .const))]
            ),
            body: [
                Statement(binding: .constant("once"), expression: .apply(reference("body"), arguments: [:])
                )
            ]
        )
        let sut = try Module(
            procedures: [
                "twice": twice,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("loud"), expression: .closure(
                                Procedure(
                                    body: [
                                        Statement(binding: .constant("said"), expression: .call(Call(
                                                selector: "app.shout",
                                                arguments: ["text": .literal(.string("hi"))]
                                            ))
                                        )
                                    ],
                                    result: reference("said")
                                )
                            )
                        ),
                        Statement(binding: .constant("ran"), expression: .call(Call(
                                selector: "twice",
                                arguments: ["body": reference("loud")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut, .shouting] + Module.standard)
        }
    }

    @Test("a slot asking for a const procedure takes one that answers")
    func aConstClosureFitsWhereConstIsAsked() async throws {
        // Given. The same declaration, handed a body that only reads
        let twice = Procedure(
            signature: Signature(
                parameters: ["body": Parameter(type: .procedure(nil, .const))],
                returns: .string
            ),
            body: [
                Statement(binding: .constant("once"), expression: .apply(reference("body"), arguments: [:])
                )
            ],
            result: reference("once")
        )
        let sut = try Module(
            procedures: [
                "twice": twice,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("quiet"), expression: .closure(
                                Procedure(body: [], result: .literal(.string("read")))
                            )
                        )
                    ],
                    result: .call(Call(
                        selector: "twice",
                        arguments: ["body": reference("quiet")]
                    ))
                )
            ]
        )

        // When
        let answer = try await run(sut)

        // Then
        #expect(answer == .string("read"))
    }

    @Test("an author can write a construct that takes a body")
    func authorWrittenControlStructure() async throws {
        // Given. `twice` is not a native procedure and not a language case. It is a
        // procedure that declares a procedure parameter and calls it, which is
        // the whole of what "the author can make constructs" means here.
        let twice = Procedure(
            signature: Signature(parameters: ["body": Parameter(type: .procedure(nil))]),
            body: [
                Statement(binding: .constant("first"), expression: .apply(reference("body"), arguments: [:])
                ),
                Statement(binding: .constant("second"), expression: .apply(reference("body"), arguments: [:])
                )
            ],
            result: .array([reference("first"), reference("second")])
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .constant("ran"), expression: .call(
                        Call(
                            selector: "twice",
                            arguments: [
                                "body": .closure(
                                    Procedure(body: [], result: .literal(.string("hi")))
                                )
                            ]
                        )
                    )
                )
            ],
            result: reference("ran"),
            beside: ["twice": twice]
        )

        // Then
        #expect(answer == .array([.string("hi"), .string("hi")]))
    }

    @Test("a procedure can answer with a procedure")
    func procedureAnswersProcedure() async throws {
        // Given. The returned closure holds the argument its maker was given,
        // which is what makes returning one worth anything
        let makeGreeter = Procedure(
            signature: Signature(parameters: ["greeting": Parameter(type: .string)]),
            body: [],
            result: .closure(
                Procedure(
                    signature: Signature(parameters: ["name": Parameter(type: .string)]),
                    body: [],
                    result: interpolated(spelling(reference("greeting")), literal(", "), spelling(reference("name")))
                )
            )
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .constant("hello"), expression: .call(
                        Call(
                            selector: "makeGreeter",
                            arguments: ["greeting": .literal(.string("hello"))]
                        )
                    )
                ),
                Statement(binding: .constant("said"), expression: .apply(
                        reference("hello"),
                        arguments: ["name": .literal(.string("warp"))]
                    )
                )
            ],
            result: reference("said"),
            beside: ["makeGreeter": makeGreeter]
        )

        // Then
        #expect(answer == .string("hello, warp"))
    }

    @Test("closures travel in arrays and records like any other value")
    func closuresTravelInStructures() async throws {
        // Given
        let sut = [
            Statement(binding: .constant("table"), expression: .record([
                    "yes": .closure(Procedure(body: [], result: .literal(.string("y")))),
                    "no": .closure(Procedure(body: [], result: .literal(.string("n"))))
                ])
            ),
            Statement(binding: .constant("picked"), expression: .apply(reference("table", "yes"), arguments: [:])
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("picked"))

        // Then
        #expect(answer == .string("y"))
    }

    @Test("calling something that is not a procedure fails with what it was")
    func callingNonProcedureFails() async {
        // Given
        let sut = [
            Statement(binding: .constant("notCallable"), expression: .literal(.int(1))),
            Statement(binding: .constant("called"), expression: .apply(reference("notCallable"), arguments: [:])
            )
        ]

        // When / Then
        await #expect(throws: ExecutionError.self) {
            try await answer(of: sut, result: reference("called"))
        }
    }

    @Test("a closure body is validated where it is written")
    func closureBodyIsValidatedAtItsSite() {
        // Given. The body may read what surrounds the literal and what the
        // literal declares, and nothing else
        let readsEnclosing = Warp.Expression.closure(
            Procedure(body: [], result: reference("outer"))
        )
        let readsItsOwn = Warp.Expression.closure(
            Procedure(
                signature: Signature(parameters: ["mine": Parameter(type: .int)]),
                body: [],
                result: reference("mine")
            )
        )
        let readsNothingReal = Warp.Expression.closure(
            Procedure(body: [], result: reference("nowhere"))
        )

        // Then
        #expect(validates(readsEnclosing, visible: ["outer"]))
        #expect(!validates(readsEnclosing))
        #expect(validates(readsItsOwn))
        #expect(!validates(readsNothingReal))
    }

    @Test("a procedure is never equal to a procedure")
    func proceduresHaveNoEquality() throws {
        // Given. There is no honest answer, so the language does not offer one
        let sut = Value.procedure(
            Closure.assembled()
        )

        // Then
        #expect(sut != sut)
        #expect(sut.type == .procedure)
    }
}

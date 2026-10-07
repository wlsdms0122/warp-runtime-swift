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
import WarpTestSupport

// A procedure is a value, so an author can write a construct that takes a
// body, and a procedure that makes one.
@Suite("A procedure is a value")
struct ClosureTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body declaring the one parameter the slot hands fits it, under any name", arguments: ["item", "anything"] as [Name])
    func aBodyDeclaringWhatTheSlotHandsFits(name: Name) async throws {
        // Given. The slot hands one value, and a value is applied by position
        let sut = try module(declaring: [Parameter(name: name, type: .int)])

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a body declaring another count than the slot hands does not fit", arguments: [
        [] as [Parameter],
        [Parameter(name: "item", type: .int), Parameter(name: "index", type: .int)]
    ])
    func aBodyDeclaringAnotherCountDoesNotFit(declared: [Parameter]) async throws {
        // Given. The slot hands one value, and a body declaring none or two is
        // a different procedure
        let sut = try module(declaring: declared)

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("where procedure<(int) -> any> is declared")
        }
    }

    @Test(
        "a value applied short or over is refused by the count",
        arguments: [
            (handed: 2, refusal: "with 2 arguments, and it takes 3"),
            (handed: 4, refusal: "with 4 arguments, and it takes 3")
        ]
    )
    func anApplicationShortOrOverSaysWhy(handed: Int, refusal: String) async throws {
        // Given. `made` takes two and a nullable third, so two arguments are
        // one short even where the missing one is nullable, and four is one
        // more than it takes
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("made"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(parameters: [
                                        Parameter(name: "a", type: .int),
                                        Parameter(name: "b", type: .int),
                                        Parameter(name: "c", type: .nullable(.int))
                                    ]),
                                    body: [],
                                    result: reference("a")
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("said"),
                            expression: .apply(
                                reference("made"),
                                arguments: Array(repeating: .literal(.int(1)), count: handed)
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains(refusal)
        }
    }

    @Test("a value taking a parameter in place, applied short, is refused by the count")
    func anApplicationShortOfAnInPlaceParameterSaysTheCount() async throws {
        // Given. `bump` takes a variable in place and an int, and is handed
        // one argument, which is no variable
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("bump"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(parameters: [
                                        Parameter(name: "c", type: .inout(.int)),
                                        Parameter(name: "d", type: .int)
                                    ]),
                                    body: []
                                )
                            )
                        ),
                        Statement(expression: .apply(reference("bump"), arguments: [.literal(.int(1))]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("with 1 arguments, and it takes 2")
        }
    }

    @Test("a closure captures the scope it was written in, not the one it runs in")
    func closureCapturesLexically() async throws {
        // Given. `made` is written where `outer` says "written", and `running`
        // applies it beside an `outer` of its own saying "called"
        let running = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "by", type: .procedure(ProcedureType(returns: .string)))],
                returns: .string
            ),
            body: [
                Statement(binding: .constant("outer"), expression: .literal(.string("called"))),
                Statement(binding: .constant("said"), expression: .apply(reference("by"), arguments: []))
            ],
            result: reference("said")
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .constant("outer"), expression: .literal(.string("written"))),
                Statement(binding: .constant("made"), expression: .closure(Procedure(body: [], result: reference("outer"))))
            ],
            result: .call(Call(selector: "running", arguments: [reference("made")])),
            beside: ["running": running]
        )

        // Then
        #expect(answer == .string("written"))
    }

    @Test("an extra parameter the slot never hands does not fit, even a nullable one")
    func anExtraParameterDoesNotFit() async throws {
        // Given. The slot hands one value and the body writes two, the second
        // nullable. A count the slot does not have is a different procedure,
        // whatever the extra parameter admits.
        let walking = Procedure(
            signature: Signature(
                parameters: [
                    Parameter(name: "by", type: .procedure(ProcedureType(parameters: [.int])))
                ]
            ),
            body: [
                Statement(
                    binding: .constant("once"),
                    expression: .apply(reference("by"), arguments: [.literal(.int(1))])
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
                                        Parameter(name: "item", type: .int),
                                        Parameter(name: "index", type: .nullable(.int))
                                    ]),
                                    body: [],
                                    result: .literal(.int(1))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("ran"),
                            expression: .call(Call(selector: "walking", arguments: [reference("body")]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds const isolated procedure<(int, int?) -> any> where procedure<(int) -> any> is declared")
        }
    }

    @Test("a slot asking for a const procedure refuses one that reaches outside")
    func aClosureThatRunsIsRefusedWhereConstIsAsked() async throws {
        // Given. `twice` declares that whatever it is handed answers without
        // running. The closure handed to it shouts, and shouting is an effect
        let twice = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "body", type: .procedure(nil, .const))]
            ),
            body: [
                Statement(binding: .constant("once"), expression: .apply(reference("body"), arguments: []))
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
                                            selector: "App.shout",
                                            arguments: [.literal(.string("hi"))]
                                        )))
                                    ],
                                    result: reference("said")
                                )
                            )
                        ),
                        Statement(binding: .constant("ran"), expression: .call(Call(
                            selector: "twice",
                            arguments: [reference("loud")]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut, .shouting] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds isolated procedure<() -> any> where const procedure is declared")
        }
    }

    @Test("a slot asking for a const procedure takes one that answers")
    func aConstClosureFitsWhereConstIsAsked() async throws {
        // Given. The same declaration, handed a body that only reads
        let twice = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "body", type: .procedure(nil, .const))],
                returns: .string
            ),
            body: [
                Statement(binding: .constant("once"), expression: .apply(reference("body"), arguments: []))
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
                        ))
                    ],
                    result: .call(Call(selector: "twice", arguments: [reference("quiet")]))
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
            signature: Signature(parameters: [Parameter(name: "body", type: .procedure(nil))]),
            body: [
                Statement(binding: .constant("first"), expression: .apply(reference("body"), arguments: [])),
                Statement(binding: .constant("second"), expression: .apply(reference("body"), arguments: []))
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
                                .closure(
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
            signature: Signature(parameters: [Parameter(name: "greeting", type: .string)]),
            body: [],
            result: .closure(
                Procedure(
                    signature: Signature(parameters: [Parameter(name: "name", type: .string)]),
                    body: [],
                    result: interpolated(spelling(reference("greeting")), literal(", "), spelling(reference("name")))
                )
            )
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .constant("hello"), expression: .call(
                    Call(selector: "makeGreeter", arguments: [.literal(.string("hello"))])
                )),
                Statement(binding: .constant("said"), expression: .apply(
                        reference("hello"),
                        arguments: [.literal(.string("warp"))]
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
        let sut: Body = [
            Statement(binding: .constant("table"), expression: .record([
                    "yes": .closure(Procedure(body: [], result: .literal(.string("y")))),
                    "no": .closure(Procedure(body: [], result: .literal(.string("n"))))
                ])
            ),
            Statement(binding: .constant("picked"), expression: .apply(reference("table", "yes"), arguments: []))
        ]

        // When
        let answer = try await answer(of: sut, result: reference("picked"))

        // Then
        #expect(answer == .string("y"))
    }

    @Test("calling a value no procedure could be is refused at the build")
    func callingNonProcedureIsRefused() async {
        // Given
        let sut: Body = [
            Statement(binding: .constant("notCallable"), expression: .literal(.int(1))),
            Statement(binding: .constant("called"), expression: .apply(reference("notCallable"), arguments: []))
        ]

        // When / Then
        await #expect {
            try await answer(of: sut, result: reference("called"))
        } throws: { error in
            error is BuildError && "\(error)".contains("calls a value of int, and only a procedure can be called")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A procedure whose slot hands one int, and an entry handing it a closure
    // that declares these parameters.
    private func module(declaring declared: [Parameter]) throws -> Module {
        let walking = Procedure(
            signature: Signature(
                parameters: [
                    Parameter(name: "by", type: .procedure(ProcedureType(parameters: [.int])))
                ]
            ),
            body: [
                Statement(
                    binding: .constant("once"),
                    expression: .apply(reference("by"), arguments: [.literal(.int(1))])
                )
            ]
        )

        return try Module(
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
                            expression: .call(Call(selector: "walking", arguments: [reference("body")]))
                        )
                    ]
                )
            ]
        )
    }
}

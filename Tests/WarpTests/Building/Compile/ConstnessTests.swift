//
//  ConstnessTests.swift
//  WarpTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// What "answers without running" holds a body to.
//
// The line is what a body reaches, not what it is written with. A branch, a
// round and a name of its own all stay inside the body, so a body holding them
// still answers from what it was handed. Reaching the run's own state does not,
// and neither does calling a value nothing said the constness of.
@Suite("What answers without running")
struct ConstnessTests {
    // MARK: - Property
    // A declaration whose slot asks for a body that answers without running,
    // so what fits here is exactly what the predicate admits.
    private let asking = Procedure(
        signature: Signature(
            parameters: [Parameter(name: "body", type: .procedure(nil, .const))],
            returns: .string
        ),
        body: [
            Statement(binding: .constant("answered"), expression: .apply(reference("body"), arguments: []))
        ],
        result: reference("answered")
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a body that branches answers without running")
    func aBranchingBodyAnswers() async throws {
        // Given. A branch that answers from one arm and falls through to the
        // other. Nothing in it reaches past the body.
        let branching = Procedure(
            body: [
                Statement(expression: .conditional(
                    .literal(.bool(true)),
                    then: [Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.string("taken")))))],
                    else: nil
                ))
            ],
            result: .literal(.string("fell through"))
        )

        // When
        let answer = try await run(try module(handing: branching))

        // Then
        #expect(answer == .string("taken"))
    }

    @Test("a body that loops answers without running")
    func aLoopingBodyAnswers() async throws {
        // Given. A round counted out and left from. A loop is grammar, and
        // grammar reaches nothing.
        let looping = Procedure(
            body: [
                Statement(expression: .loop(
                    while: .literal(.bool(true)),
                    body: Block(body: [
                        Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.string("counted")))))
                    ])
                ))
            ],
            result: .literal(.string("never reached"))
        )

        // When
        let answer = try await run(try module(handing: looping))

        // Then
        #expect(answer == .string("counted"))
    }

    @Test("a body that binds a variable of its own answers without running")
    func aBodyBindingAVariableAnswers() async throws {
        // Given. A name the body declares and writes. It is the body's own, so
        // nothing outside the body can tell it happened.
        let writing = Procedure(
            body: [
                Statement(binding: .variable("held"), expression: .literal(.string("first"))),
                Statement(binding: .assignment([.key("held")]), expression: .literal(.string("second")))
            ],
            result: reference("held")
        )

        // When
        let answer = try await run(try module(handing: writing))

        // Then
        #expect(answer == .string("second"))
    }

    @Test("a body reaching the module's own state does not answer without running")
    func aBodyReadingAModuleVariableIsRefused() async throws {
        // Given. The same shape, reading a name the module holds rather than
        // one the body declared. What that answers is the run's, not the text's.
        let reading = Procedure(body: [], result: reference("standing"))
        let handed = try Module(
            variables: ["standing": .literal(.string("held"))],
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    body: [Statement(binding: .constant("given"), expression: .closure(reading))],
                    result: .call(Call(selector: "asking", arguments: [reference("given")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds isolated procedure<() -> any> where const procedure is declared")
        }
    }

    @Test("a closure writing a variable it captured does not answer without running")
    func aClosureWritingACapturedVariableIsRefused() async throws {
        // Given. A closure that writes a variable the body around it declared.
        // The box is outside the closure, so the write reaches the run's state.
        let writing = Procedure(
            body: [Statement(binding: .assignment([.key("tally")]), expression: .literal(.int(1)))],
            result: .literal(.string("written"))
        )
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("tally"), expression: .literal(.int(0))),
                        Statement(binding: .constant("given"), expression: .closure(writing))
                    ],
                    result: .call(Call(selector: "asking", arguments: [reference("given")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds procedure<() -> any> where const procedure is declared")
        }
    }

    @Test("a body writing through a parameter handed in place does not answer without running, and neither does one sending it")
    func aBodyWritingInPlaceIsRefused() async throws {
        // Given. A declaration writing its in-place parameter, and a closure
        // handing a variable of its own to it. The parameter is the caller's
        // box, so the declaration runs, and the closure sends what runs.
        let bumping = Procedure(
            signature: Signature(parameters: [Parameter(name: "count", type: .inout(.int))]),
            body: [Statement(binding: .assignment([.key("count")]), expression: .literal(.int(1)))]
        )
        let sending = Procedure(
            body: [
                Statement(binding: .variable("own"), expression: .literal(.int(0))),
                Statement(expression: .call(Call(selector: "bumping", arguments: [reference("own")])))
            ],
            result: .literal(.string("sent"))
        )
        let handed = try Module(
            procedures: [
                "asking": asking,
                "bumping": bumping,
                entryName: Procedure(
                    access: .public,
                    body: [Statement(binding: .constant("given"), expression: .closure(sending))],
                    result: .call(Call(selector: "asking", arguments: [reference("given")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds isolated procedure<() -> any> where const procedure is declared")
        }
    }

    @Test("a body applying a name a slot said holds a const procedure answers without running")
    func aBodyApplyingAConstProcedureSlotAnswers() async throws {
        // Given. `asking` applies what it was handed, and its slot asks for a
        // procedure that answers without running. A closure calling `asking`
        // therefore answers without running too, and standing in that same
        // slot is where that is asked.
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("answering"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .literal(.string("answered"))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("relaying"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .call(
                                        Call(selector: "asking", arguments: [reference("answering")])
                                    )
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "asking", arguments: [reference("relaying")]))
                )
            ]
        )

        // When
        let answer = try await run(handed)

        // Then
        #expect(answer == .string("answered"))
    }

    @Test("a variable declared to hold a const procedure carries that into a closure that captured it")
    func aDeclaredVariableCarriesItsClaimIntoACapture() async throws {
        // Given. The variable says what it holds, so every write into it is
        // held to that, and a closure capturing it applies what the
        // declaration said
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .variable("answering", declared: .procedure(ProcedureType(returns: .string), .const)),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .literal(.string("answered"))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("relaying"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .apply(reference("answering"), arguments: [])
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "asking", arguments: [reference("relaying")]))
                )
            ]
        )

        // When
        let answer = try await run(handed)

        // Then
        #expect(answer == .string("answered"))
    }

    @Test("a variable that may be retyped says nothing a closure that captured it can apply as const")
    func aRetypableVariableCarriesNoClaimIntoACapture() async throws {
        // Given. The same capture, of a variable that declared nothing. A
        // write after the capture may put any procedure in it
        let handed = try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .variable("answering"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .literal(.string("answered"))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("relaying"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .apply(reference("answering"), arguments: [])
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "asking", arguments: [reference("relaying")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds procedure<() -> string> where const procedure is declared")
        }
    }

    @Test("a body applying a name no slot said anything about is refused")
    func aBodyApplyingAnUndeclaredNameIsRefused() async throws {
        // Given. The same apply, on a name whose slot says only `procedure`.
        // Nothing before the run says which procedure that holds.
        let relaying = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "body", type: .procedure(nil))],
                returns: .string
            ),
            body: [],
            result: .apply(reference("body"), arguments: [])
        )
        let handed = try Module(
            procedures: [
                "asking": asking,
                "relaying": relaying,
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("answering"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .literal(.string("answered"))
                                )
                            )
                        ),
                        Statement(
                            binding: .constant("given"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(returns: .string),
                                    body: [],
                                    result: .call(
                                        Call(selector: "relaying", arguments: [reference("answering")])
                                    )
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "asking", arguments: [reference("given")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("which holds procedure<() -> string> where const procedure is declared")
        }
    }

    @Test("a variable's starting value is read rather than run")
    func aVariableStartingFromAConstructIsRefused() async throws {
        // Given. A module variable written from a construct. A construct runs
        // a body, and the build settles a starting value by reading it.
        let handed = try Module(
            variables: ["standing": .conditional(
                .literal(.bool(true)),
                then: [Statement(binding: .constant("kept"), expression: .literal(.int(1)))],
                else: nil
            )],
            procedures: [entryName: Procedure(access: .public, body: [], result: reference("standing"))]
        )

        // When / Then
        await #expect {
            try await Builder().build([handed] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("a construct runs a body, and a call's operand is data")
        }
    }

    @Test("what answers without running is worked out at the build, not declared")
    func constnessIsABuildFact() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "clean": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .literal(.int(1)))
                    ]
                ),
                "dirty": Procedure(
                    body: [
                        Statement(binding: .constant("done"), expression: .call(Call(
                            selector: "App.fail",
                            arguments: [.literal(.bool(true))]
                        )))
                    ]
                ),
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("a"), expression: .call(Call(selector: "clean"))),
                        Statement(binding: .constant("b"), expression: .call(Call(selector: "dirty")))
                    ]
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard + [.failing])

        // Then. `clean` computes; `dirty` reaches an effect, and everything
        // that reaches it goes with it
        let dirty = try #require(image["dirty"])
        let entry = try #require(image["entry"])

        #expect(image["clean"]?.constness == .const)
        #expect(dirty.constness != .const)
        #expect(entry.constness != .const)
        #expect(image["Standard.Collection.count"]?.constness == .const)
    }

    @Test("a body that sends a const procedure is const")
    func aBodyThatSendsIsStillConst() async throws {
        // Given. Constness is judged over the name a body wrote, and what that
        // name means depends on where it was written. `label` sends `joined`,
        // which is const, so `label` is const
        let label = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "of", type: .array(.string))],
                returns: .string
            ),
            body: [],
            result: .call(Call(selector: "Standard.Text.joined", arguments: [reference("of"), .literal(.string(""))]))
        )
        let sut = try Module(
            procedures: [
                "label": label,
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "names", type: .array(.string))]
                    ),
                    body: [],
                    result: .call(Call(selector: "label", arguments: [reference("names")]))
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["label"]?.constness == .const)
    }

    // MARK: - Public
    // MARK: - Private
    // The declaration above, handed the body under test.
    private func module(handing body: Procedure) throws -> Module {
        try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    access: .public,
                    body: [Statement(binding: .constant("given"), expression: .closure(body))],
                    result: .call(Call(selector: "asking", arguments: [reference("given")]))
                )
            ]
        )
    }
}

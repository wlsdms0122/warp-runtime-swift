//
//  ControlFlowTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

@Suite("Control flow as it runs")
struct ControlFlowTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a block answers what it says it answers, and nothing if it says nothing")
    func aBlockAnswersOnlyWhatItDeclares() async throws {
        // Given. Reading the last statement instead would put the answer in the
        // ordering, where nothing points at it. Appending a statement would
        // change what the block was worth, and the author who appended it wrote
        // nothing that says so.
        let sut = Warp.Expression.block(
            Block(body: [
                Statement(binding: .constant("first"), expression: .literal(.int(1))),
                Statement(binding: .constant("second"), expression: .literal(.int(2)))
            ])
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .null)
    }

    @Test("a declared result outranks the last statement")
    func declaredResultOutranksLastStatement() async throws {
        // Given
        let sut = Warp.Expression.block(
            Block(
                body: [
                    Statement(binding: .constant("first"), expression: .literal(.int(1))),
                    Statement(binding: .constant("second"), expression: .literal(.int(2)))
                ],
                result: reference("first")
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .int(1))
    }

    @Test("a conditional answers nothing, and what an arm keeps it writes outward")
    func aBranchAnswersNothingAndWritesOutward() async throws {
        // Given. The condition chooses a way through the body, not a value:
        // either arm writes the enclosing variable, and that write is the whole
        // of what the conditional leaves behind
        let sut = { (take: Bool) in
            Warp.Expression.conditional(
                .literal(.bool(take)),
                then: [
                    Statement(binding: .assignment([.key("kept")]), expression: .literal(.string("then")))
                ],
                else: [
                    Statement(binding: .assignment([.key("kept")]), expression: .literal(.string("else")))
                ]
            )
        }

        // When
        let taken = try await answer(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.string(""))),
                Statement(expression: sut(true))
            ],
            result: reference("kept")
        )
        let untaken = try await answer(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.string(""))),
                Statement(expression: sut(false))
            ],
            result: reference("kept")
        )

        // Then
        #expect(taken == .string("then"))
        #expect(untaken == .string("else"))
    }

    @Test("a declining conditional leaves the enclosing names as they were")
    func aDecliningBranchWritesNothing() async throws {
        // Given. With no other arm, a condition that declines runs nothing: the
        // variable holds what it held, which is the null it started with
        let sut = Warp.Expression.conditional(
            .literal(.bool(false)),
            then: [
                Statement(binding: .assignment([.key("kept")]), expression: .literal(.string("then")))
            ],
            else: nil
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.null)),
                Statement(expression: sut)
            ],
            result: reference("kept")
        )

        // Then
        #expect(answer == .null)
    }

    @Test("a loop's result reads a name its body declared as the body's, whatever the entry holds under it")
    func aLoopResultReadsTheBodysOwnDeclaration() async throws {
        // Given. The entry holds `x` in a box declared `Int`. The body declares
        // its own `x`, a string, and the result reads that one: null where no
        // round ran, and the body's otherwise
        let loop = Warp.Expression.loop(
            while: differs(reference("probe", "index"), .literal(.int(1))),
            body: Block(
                body: [Statement(binding: .variable("x"), expression: .literal(.string("s")))],
                result: reference("x")
            )
        )
        let sut = try Module(
            imports: ["Standard.Logic.notEqual"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("x", declared: .int), expression: .literal(.int(1))),
                        Statement(binding: .constant("probe"), expression: loop)
                    ],
                    result: reference("probe")
                )
            ]
        )

        // When
        let compiled = try await Builder().compile([sut] + Module.standard)
        let answered = compiled.compactMap { document in document.answers[entryName] }.first

        // Then. The reading is the body's string, nullable for the exit no
        // round reached, and not the entry's int joined into anything
        #expect(answered == .nullable(.string))
        let image = try await Builder().build([sut] + Module.standard)
        #expect(try await Executor().run(image) == .string("s"))
    }

    @Test("a loop reads how many rounds have passed")
    func loopReadsItsRoundIndex() async throws {
        // Given
        let sut = Warp.Expression.loop(
            while: differs(reference("probe", "index"), .literal(.int(3))),
            body: Block(body: [Statement(binding: .constant("tick"), expression: reference("probe", "index"))])
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then. The loop answers null without a declared result, which is
        // what its name reads after it
        #expect(answer == .null)
    }

    @Test("an author bounds a loop with the language it already has")
    func anAuthorBoundsALoopWithACounterAndAbort() async throws {
        // Given. Repetition carries no budget of its own; a counter in the
        // condition and `abort` past the bound say it exactly, and the failure
        // is a procedure's failure like any other
        let sut = Warp.Expression.loop(
            while: .call(
                Call(selector: "Standard.Comparable.lessThan", arguments: [reference("probe", "index"), .literal(.int(3))])
            ),
            body: Block(body: [
                Statement(
                    expression: .conditional(
                        .call(
                            Call(
                                selector: "Standard.Logic.equal",
                                arguments: [reference("probe", "index"), .literal(.int(2))]
                            )
                        ),
                        then: [
                            Statement(
                                expression: .call(
                                    Call(
                                        selector: "Standard.Control.abort",
                                        arguments: [.literal(.string("too many rounds"))]
                                    )
                                )
                            )
                        ],
                        else: nil
                    )
                )
            ])
        )

        // When / Then
        await #expect(throws: Aborted.self) {
            try await answer(
                of: [Statement(binding: .constant("probe"), expression: sut)],
                result: reference("probe")
            )
        }
    }

    @Test("a walk over a collection is a loop over its count")
    func aWalkIsALoopOverTheCount() async throws {
        // Given. Repetition is one construct. Walking a collection is the round
        // read against the material's count, with the element read at that
        // index, and a round's contribution is what it writes outward
        let sut = walking(
            [.key("counts")],
            element: "element",
            body: [
                Statement(binding: .assignment([.key("sum")]), expression: .call(
                    Call(selector: "Standard.Numeric.plus", arguments: [reference("sum"), reference("element")])
                ))
            ]
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .variable("sum"), expression: .literal(.int(0))),
                Statement(binding: .constant("walk"), expression: sut)
            ],
            result: reference("sum"),
            arguments: ["counts": .array([.int(1), .int(2), .int(3)])],
            signature: Signature(parameters: [Parameter(name: "counts", type: .array(.int))])
        )

        // Then
        #expect(answer == .int(6))
    }

    @Test("an author mistake passes through a rescue")
    func authorMistakeIsNotRescued() async throws {
        // Given. Recovery is for a world that did not cooperate, not for a
        // procedure that is wrong
        let sut = Warp.Expression.attempt(
            Block(body: [
                Statement(binding: .constant("boom"), expression: .call(
                    Call(selector: "App.fail", arguments: [.literal(.bool(false))])
                ))
            ]),
            rescue: Block(body: [], result: .literal(.string("recovered")))
        )

        // When / Then
        await #expect(throws: TestFatalError.self) {
            try await answer(
                of: [Statement(binding: .constant("probe"), expression: sut)],
                result: reference("probe"),
                vocabulary: Module.standard + [.failing]
            )
        }
    }

    @Test("a body a native procedure calls leaves for itself, not for the procedure around it")
    func aBodyANativeProcedureCallsLeavesForItself() async throws {
        // Given. The same early leave, reached through a native procedure that
        // calls the body once per element rather than through `apply`.
        let judging = Procedure(
            signature: Signature(parameters: [Parameter(name: "item", type: .int)], returns: .bool),
            body: [
                Statement(expression: .conditional(
                    equals(reference("item"), .literal(.int(2))),
                    then: [Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.bool(true)))))],
                    else: nil
                ))
            ],
            result: .literal(.bool(false))
        )
        let asking = Procedure(
            body: [Statement(binding: .constant("judging"), expression: .closure(judging))],
            result: .call(
                Call(
                    selector: "Standard.Collection.filter",
                    arguments: [.array([.literal(.int(1)), .literal(.int(2)), .literal(.int(3))]), reference("judging")]
                )
            )
        )

        // When
        let answer = try await run(asking)

        // Then. A leave answering for the procedure around it would end the
        // whole run at the first element instead.
        #expect(answer == .array([.int(2)]))
    }

    // MARK: - Public
    // MARK: - Private
}

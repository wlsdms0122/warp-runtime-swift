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

// Control flow is a closed set of expression cases the language owns, so each
// one is asked here directly. What it answers with, and what its body can see.
@Suite
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

    @Test("what a block binds does not escape it")
    func blockBindingsDoNotEscape() {
        // Given
        let sut: [Statement] = [
            Statement(binding: .constant("probe"), expression: .block(
                    Block(body: [Statement(binding: .constant("inner"), expression: .literal(.int(1)))])
                )
            ),
            Statement(binding: .constant("read"), expression: reference("inner"))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a branch answers nothing, and what an arm keeps it writes outward")
    func aBranchAnswersNothingAndWritesOutward() async throws {
        // Given. The condition chooses a way through the body, not a value:
        // either arm writes the enclosing variable, and that write is the whole
        // of what the branch leaves behind
        let sut = { (take: Bool) in
            Warp.Expression.conditional(
                .literal(.bool(take)),
                then: [
                    Statement(binding: .assignment([.key("kept")]), expression: .literal(.string("then"))
                    )
                ],
                else: [
                    Statement(binding: .assignment([.key("kept")]), expression: .literal(.string("else"))
                    )
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

    @Test("a declining branch leaves the enclosing names as they were")
    func aDecliningBranchWritesNothing() async throws {
        // Given, with no other arm, a condition that declines runs nothing: the
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

    @Test("a name on a branch is refused")
    func aNameOnABranchIsRefused() {
        // Given. A branch answers nothing, so its name could never bind
        let sut = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [Statement(expression: .literal(.int(1)))],
            else: nil
        )

        // When / Then. Under any of the three spellings
        #expect(!validates(body: [Statement(binding: .constant("probe"), expression: sut)]))
        #expect(!validates(body: [Statement(binding: .variable("probe"), expression: sut)]))
        #expect(
            !validates(body: [
                Statement(binding: .variable("probe"), expression: .literal(.int(0))),
                Statement(binding: .assignment([.key("probe")]), expression: sut)
            ])
        )
    }

    @Test("a loop reads how many rounds have passed")
    func loopReadsItsRoundIndex() async throws {
        // Given
        let sut = Warp.Expression.loop(
            while: differs(reference("round", "index"), .literal(.int(3))),
            body: Block(body: [Statement(binding: .constant("tick"), expression: reference("round", "index"))]),
            round: "round"
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then. The loop answers null without a declared result, and the round
        // state is the loop's own: it is not visible after it
        #expect(answer == .null)
        #expect(
            !validates(
                body: [
                    Statement(binding: .constant("probe"), expression: sut),
                    Statement(binding: .constant("rounds"), expression: reference("round", "index"))
                ]
            )
        )
    }

    @Test("an author bounds a loop with the language it already has")
    func anAuthorBoundsALoopWithACounterAndAbort() async throws {
        // Given. Repetition carries no budget of its own; a counter in the
        // condition and `abort` past the bound say it exactly, and the failure
        // is a word's failure like any other
        let sut = Warp.Expression.loop(
            while: .call(
                Call(
                    receiver: reference("round", "index"),
                    selector: "std.math.lessThan",
                    arguments: ["value": .literal(.int(3))]
                )
            ),
            body: Block(body: [
                Statement(
                    expression: .conditional(
                        .call(
                            Call(
                                receiver: reference("round", "index"),
                                selector: "std.logic.equal",
                                arguments: ["value": .literal(.int(2))]
                            )
                        ),
                        then: [
                            Statement(
                                expression: .call(
                                    Call(
                                        receiver: .literal(.string("too many rounds")),
                                        selector: "std.control.abort"
                                    )
                                )
                            )
                        ],
                        else: nil
                    )
                )
            ]),
            round: "round"
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
                        Call(
                            receiver: reference("sum"),
                            selector: "std.math.plus",
                            arguments: ["value": reference("element")]
                        )
                    )
                )
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
            signature: Signature(parameters: ["counts": Parameter(type: .array(.int))])
        )

        // Then
        #expect(answer == .int(6))
    }

    @Test("a rescue runs on a recoverable failure and can read it")
    func rescueRunsAndReadsTheFailure() async throws {
        // Given
        let sut = Warp.Expression.attempt(
            Block(body: [
                Statement(binding: .constant("boom"), expression: .call(
                        Call(
                            selector: "app.fail",
                            arguments: ["recoverable": .literal(.bool(true))]
                        )
                    )
                )
            ]),
            rescue: Block(body: [], result: reference("failure", "message")),
            failure: "failure"
        )

        // When
        let answer = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe"),
            vocabulary: Module.standard + [.failing]
        )

        // Then
        #expect(answer == .string("the world did not cooperate"))
    }

    @Test("an author mistake passes through a rescue")
    func authorMistakeIsNotRescued() async throws {
        // Given. Recovery is for a world that did not cooperate, not for a
        // procedure that is wrong
        let sut = Warp.Expression.attempt(
            Block(body: [
                Statement(binding: .constant("boom"), expression: .call(
                        Call(
                            selector: "app.fail",
                            arguments: ["recoverable": .literal(.bool(false))]
                        )
                    )
                )
            ]),
            rescue: Block(body: [], result: .literal(.string("recovered"))),
            failure: "failure"
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

    @Test("an empty rescue is refused")
    func emptyRescueRefused() {
        // Given. A rescue that produces nothing swallows a failure into null
        // without a trace
        let sut = Warp.Expression.attempt(
            Block(body: [Statement(binding: .constant("work"), expression: .literal(.int(1)))]),
            rescue: Block(body: []),
            failure: "failure"
        )

        // When / Then
        #expect(!validates(sut))
    }
}

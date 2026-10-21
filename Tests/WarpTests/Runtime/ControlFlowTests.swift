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
    @Test("a conditional answers nothing, and what an arm keeps it writes outward")
    func aBranchAnswersNothingAndWritesOutward() async throws {
        // Given. The condition chooses a way through the body, not a value:
        // either arm writes the enclosing variable, and that write is the whole
        // of what the conditional leaves behind
        let sut = { (take: Bool) in
            Warp.Expression.conditional(
                .literal(.bool(take)),
                then: [
                    Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("then")))
                ],
                else: [
                    Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("else")))
                ]
            )
        }

        // When
        let taken = try await answer(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.string(""))),
                Statement(expression: sut(true))
            ],
            returning: reference("kept")
        )
        let untaken = try await answer(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.string(""))),
                Statement(expression: sut(false))
            ],
            returning: reference("kept")
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
                Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("then")))
            ],
            else: nil
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.null)),
                Statement(expression: sut)
            ],
            returning: reference("kept")
        )

        // Then
        #expect(answer == .null)
    }

    @Test("a loop reads how many rounds have passed")
    func loopReadsItsRoundIndex() async throws {
        // Given
        let sut = Warp.Expression.loop(
            while: differs(reference("probe", "index"), .literal(.int(3))),
            body: [Statement(binding: .assignment([.name("seen")]), expression: reference("probe", "index"))]
        )

        // When
        let answer = try await answer(
            of: [
                Statement(binding: .variable("seen"), expression: .literal(.int(-1))),
                Statement(binding: .constant("probe"), expression: sut)
            ],
            returning: reference("seen")
        )

        // Then. The last round to run was the one the index read 2 in
        #expect(answer == .int(2))
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
            body: [
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
            ]
        )

        // When / Then
        await #expect(throws: Aborted.self) {
            try await answer(
                of: [Statement(binding: .constant("probe"), expression: sut)],
                returning: .literal(.null)
            )
        }
    }

    @Test("a walk over a collection is a loop over its count")
    func aWalkIsALoopOverTheCount() async throws {
        // Given. Repetition is one construct. Walking a collection is the round
        // read against the material's count, with the element read at that
        // index, and a round's contribution is what it writes outward
        let sut = walking(
            [.name("counts")],
            element: "element",
            body: [
                Statement(binding: .assignment([.name("sum")]), expression: .call(
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
            returning: reference("sum"),
            arguments: ["counts": .array([.int(1), .int(2), .int(3)])],
            signature: Signature(parameters: [Parameter(name: "counts", type: .array(.int))], returns: .int)
        )

        // Then
        #expect(answer == .int(6))
    }

    @Test("an author mistake passes through a rescue")
    func authorMistakeIsNotRescued() async throws {
        // Given. Recovery is for a world that did not cooperate, not for a
        // procedure that is wrong
        let sut = Warp.Expression.attempt(
            [
                Statement(binding: .constant("boom"), expression: .call(
                    Call(selector: "App.fail", arguments: [.literal(.bool(false))])
                ))
            ],
            rescue: [Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("recovered")))]
        )

        // When / Then
        await #expect(throws: TestFatalError.self) {
            try await answer(
                of: [
                    Statement(binding: .variable("kept"), expression: .literal(.null)),
                    Statement(binding: .constant("probe"), expression: sut)
                ],
                returning: reference("kept"),
                vocabulary: Module.standard + [.failing]
            )
        }
    }

    @Test("a body a native procedure calls leaves for itself, not for the procedure around it")
    func aBodyANativeProcedureCallsLeavesForItself() async throws {
        // Given. The same early leave, reached through a native procedure that
        // calls the body once per element rather than through `apply`.
        let judging = Procedure(
            signature: Signature(
                parameters: [Parameter(name: "item", type: .int)],
                returns: .bool,
                constness: .const,
                isolation: .isolated
            ),
            body: [
                Statement(expression: .conditional(
                    equals(reference("item"), .literal(.int(2))),
                    then: [Statement(expression: .leave(.procedure(.literal(.bool(true)))))],
                    else: nil
                )),
                returning(.literal(.bool(false)))
            ]
        )
        let asking = Procedure(
            signature: Signature(returns: .array(.int)),
            body: [
                Statement(binding: .constant("judging"), expression: .closure(judging)),
                returning(.call(
                    Call(
                        selector: "Standard.Collection.filter",
                        arguments: [.array([.literal(.int(1)), .literal(.int(2)), .literal(.int(3))]), reference("judging")]
                    )
                ))
            ]
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

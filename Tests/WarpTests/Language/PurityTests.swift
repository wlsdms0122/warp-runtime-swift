//
//  PurityTests.swift
//  WarpTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What "answers without running" holds a body to.
//
// The line is what a body reaches, not what it is written with. A branch, a
// round and a name of its own all stay inside the body, so a body holding them
// still answers from what it was handed. Reaching the run's own state does not,
// and neither does calling a value nothing said the purity of.
@Suite("What answers without running")
struct PurityTests {
    // MARK: - Property
    // A declaration whose slot asks for a body that answers without running,
    // so what fits here is exactly what the predicate admits.
    private let asking = Procedure(
        signature: Signature(
            parameters: ["body": Parameter(type: .procedure(nil, .pure))],
            returns: .string
        ),
        body: [
            Statement(binding: .constant("answered"), expression: .apply(reference("body"), arguments: [:]))
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
                    ]),
                    round: "round"
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

    @Test("a body a native procedure calls leaves for itself, not for the procedure around it")
    func aBodyANativeProcedureCallsLeavesForItself() async throws {
        // Given. The same early leave, reached through a native procedure that
        // calls the body once per element rather than through `apply`.
        let judging = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .bool),
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
                    receiver: .array([.literal(.int(1)), .literal(.int(2)), .literal(.int(3))]),
                    selector: "std.collection.filter",
                    arguments: ["value": reference("judging")]
                )
            )
        )

        // When
        let answer = try await run(asking)

        // Then. A leave answering for the procedure around it would end the
        // whole run at the first element instead.
        #expect(answer == .array([.int(2)]))
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
                    body: [Statement(binding: .constant("given"), expression: .closure(reading))],
                    result: .call(Call(selector: "asking", arguments: ["body": reference("given")]))
                )
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([handed] + Module.standard, entry: entryName)
        }
    }

    @Test("a variable's starting value is read rather than run")
    func aVariableStartingFromAConstructIsRefused() async throws {
        // Given. A module variable written from a construct. A construct runs
        // a body, and the build settles a starting value by reading it.
        //
        // Written as a module rather than as a document: the validator refuses
        // this where a document is loaded, so what is asked here is the
        // judgement an artifact carrying the same shape meets.
        let handed = try Module(
            variables: ["standing": .conditional(
                .literal(.bool(true)),
                then: [Statement(binding: .constant("kept"), expression: .literal(.int(1)))],
                else: nil
            )],
            procedures: [entryName: Procedure(body: [], result: reference("standing"))]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([handed] + Module.standard, entry: entryName)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The declaration above, handed the body under test.
    private func module(handing body: Procedure) throws -> Module {
        try Module(
            procedures: [
                "asking": asking,
                entryName: Procedure(
                    body: [Statement(binding: .constant("given"), expression: .closure(body))],
                    result: .call(Call(selector: "asking", arguments: ["body": reference("given")]))
                )
            ]
        )
    }
}

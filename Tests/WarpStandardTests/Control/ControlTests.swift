//
//  ControlTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpStandard
import WarpTestSupport

@Suite("What Standard.Control answers")
struct ControlTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("abort fails carrying its rendered message")
    func abortFailsWithItsMessage() async throws {
        // Given
        let sut = aborting(interpolated(literal("no: "), spelling(reference("reason"))))

        // When / Then. Nameless and last, with no result: nothing may be
        // written after what never finishes, so the procedure ends with it
        await #expect {
            try await run(
                Procedure(
                    signature: Signature(parameters: [Parameter(name: "reason", type: .string)]),
                    body: [Statement(expression: sut)]
                ),
                arguments: ["reason": .string("out of room")]
            )
        } throws: { error in
            (error as? Aborted)?.message == "no: out of room"
        }
    }

    @Test("an abort is caught by an attempt around it")
    func abortIsRecoverable() async throws {
        // Given. `RecoverableFailure` is what separates a failure from the
        // author being wrong, and an abort is the first kind
        let sut = Warp.Expression.attempt(
            Block(body: [Statement(expression: aborting(literal("stopped")))]),
            rescue: Block(body: [], result: .literal(.string("caught")))
        )

        // When
        let answered = try await answer(
            of: [Statement(binding: .constant("probe"), expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answered == .string("caught"))
    }

    @Test("an arm that aborts does not decide what the arm that stays holds")
    func abortDoesNotWidenTheOtherArm() async throws {
        // Given. `returns: Never` is what keeps the conditional a string. Were it
        // `Any`, the consumer below would be allowed to disagree with it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "ok", type: .bool)]),
                    body: [
                        Statement(binding: .variable("either"), expression: .literal(.null)
                        ),
                        Statement(
                            expression: .conditional(
                                reference("ok"),
                                then: [
                                    Statement(binding: .assignment([.name("either")]), expression: .literal(.string("here"))
                                    )
                                ],
                                else: [Statement(expression: aborting(literal("gone")))]
                            )
                        ),
                        Statement(binding: .constant("used"), expression: .call(
                                Call(selector: "wants", arguments: [reference("either")])
                            )
                        )
                    ]
                ),
                "App.wants": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then. The conditional holds a string, and `wants` declares an int
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

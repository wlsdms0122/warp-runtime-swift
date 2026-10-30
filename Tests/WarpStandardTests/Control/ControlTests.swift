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

@Suite("What Standard.Control returns")
struct ControlTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("abort fails carrying its rendered message")
    func abortFailsWithItsMessage() async throws {
        // Given
        let sut = aborting(joined(literal("no: "), spelling(reference("reason"))))

        // When / Then. Nameless and last: nothing may be
        // written after what never finishes, so the procedure ends with it
        await #expect {
            try await run(
                Procedure(
                    signature: Signature(parameters: [Parameter(name: "reason", type: .string)], failing: .these(["aborted"])),
                    body: [Statement(expression: sut)]
                ),
                arguments: ["reason": .string("out of room")]
            )
        } throws: { error in
            (error as? Aborted)?.message == "no: out of room"
        }
    }

    @Test("an abort is caught by a try around it")
    func abortIsRecoverable() async throws {
        // Given. `RecoverableFailure` is what separates a failure from the
        // author being wrong, and an abort is the first kind
        let sut = Warp.Expression.try(
            [Statement(expression: aborting(literal("stopped")))],
            catch: [Statement(binding: .assignment([.name("kept")]), expression: .literal(.string("caught")))]
        )

        // When
        let returned = try await returned(
            of: [
                Statement(binding: .variable("kept"), expression: .literal(.null)),
                Statement(binding: .constant("probe"), expression: sut)
            ],
            returning: reference("kept")
        )

        // Then
        #expect(returned == .string("caught"))
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

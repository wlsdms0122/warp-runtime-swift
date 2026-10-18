//
//  FailingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// What a body may fail with, before it runs. A native procedure says what it raises
// and a body is read off what it casts, calls and rescues, so the build can
// answer what the whole program may fail with and can tell an author their
// rescue is a body no run reaches.
@Suite("What may come out of a body")
struct FailingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body that casts and calls nothing that fails, fails nothing")
    func aQuietBodyFailsNothing() async throws {
        // Given. `plus` throws only at an author mistake, so it fails nothing
        let sut = try Module(
            imports: ["Standard.Numeric.plus"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(
                        Call(selector: "Standard.Numeric.plus", arguments: [.literal(.int(1)), .literal(.int(2))])
                    )
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image[entryName]?.failing == .these([]))
    }

    @Test("a procedure that raises is read through whatever calls it")
    func aRaisingProcedureCarriesToItsCallers() async throws {
        // Given
        let sut = try Module(
            imports: ["Standard.Control.abort"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(selector: "App.reach"))
                ),
                "App.reach": Procedure(
                    body: [],
                    result: .call(
                        Call(selector: "Standard.Control.abort", arguments: [.literal(.string("no"))])
                    )
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image["App.reach"]?.failing == .these(["aborted"]))
        #expect(image[entryName]?.failing == .these(["aborted"]))
    }

    @Test("abort sent null says the default message")
    func abortSentNullSaysTheDefault() async throws {
        // Given. `abort` takes `of: Any`, and null is a value `Any` admits.
        // Null spells nothing, and a refusal says something
        let sut = try Module(
            imports: ["Standard.Control.abort"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .any)]),
                    body: [],
                    result: .call(Call(selector: "Standard.Control.abort", arguments: [reference("it")]))
                )
            ]
        )
        let image = try await Builder().build([sut] + Module.standard)

        // When / Then
        let aborted = await #expect(throws: Aborted.self) {
            try await Executor().run(image, arguments: ["it": .null])
        }

        #expect(aborted?.message == "aborted")
    }

    @Test("a plain cast is what the runtime itself may fail with")
    func aPlainCastFails() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .any)]),
                    body: [],
                    result: .cast(reference("it"), as: .int, optional: false)
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then. The optional spelling reads the mismatch as null instead
        #expect(image[entryName]?.failing == .these(["cast_refused"]))
    }

    @Test("a rescue takes the body's failures off, and adds its own")
    func aRescueClearsWhatTheBodyRaises() async throws {
        // Given. The body aborts, the rescue casts
        let sut = try Module(
            imports: ["Standard.Control.abort"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .any)]),
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(body: [], result: .call(
                                    Call(selector: "Standard.Control.abort", arguments: [.literal(.string("no"))])
                                )),
                                rescue: Block(
                                    body: [],
                                    result: .cast(reference("it"), as: .int, optional: false)
                                )
                            )
                        )
                    ],
                    result: reference("tried")
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image[entryName]?.failing == .these(["cast_refused"]))
    }

    @Test("a rescue over a body that cannot fail refuses")
    func aDeadRescueRefuses() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(body: [], result: .literal(.int(1))),
                                rescue: Block(body: [], result: .literal(.int(2)))
                            )
                        )
                    ],
                    result: reference("tried")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("attempts a body that cannot fail")
        }
    }

    @Test("calling a value leaves the question open, so an attempt over one stands")
    func applyingAValueSaysNothing() async throws {
        // Given. Which value is called is decided at run time
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "piece", type: .procedure(ProcedureType(returns: .int, failing: .unstated)))]
                    ),
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(body: [], result: .apply(reference("piece"), arguments: [])),
                                rescue: Block(body: [], result: .literal(.int(2)))
                            )
                        )
                    ],
                    result: reference("tried")
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then. The rescue caught an unknown, and what is left is the rescue's
        #expect(image[entryName]?.failing == .these([]))
    }

    // MARK: - Public
    // MARK: - Private
}

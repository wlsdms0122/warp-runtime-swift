//
//  FailingTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What a body may fail with, before it runs. A native word says what it raises
// and a body is read off what it casts, calls and rescues, so the link can
// answer what the whole program may fail with and can tell an author their
// rescue is a body no run reaches.
@Suite("What may come out of a body")
struct FailingTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a body that casts and calls nothing that fails, fails nothing")
    func aQuietBodyFailsNothing() throws {
        // Given. `plus` throws only at an author mistake, so it fails nothing
        let sut = try Module(
            imports: ["std.math.plus"],
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(
                        Call(
                            receiver: .literal(.int(1)),
                            selector: "std.math.plus",
                            arguments: ["value": .literal(.int(2))]
                        )
                    )
                )
            ]
        )

        // When
        let image = try Builder().build([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image[entryName]?.failing == .these([]))
    }

    @Test("a word that raises is read through whatever calls it")
    func aRaisingWordCarriesToItsCallers() throws {
        // Given
        let sut = try Module(
            imports: ["std.control.abort"],
            procedures: [
                entryName: Procedure(
                    body: [],
                    result: .call(Call(selector: "app.reach"))
                ),
                "app.reach": Procedure(
                    body: [],
                    result: .call(
                        Call(receiver: .literal(.string("no")), selector: "std.control.abort")
                    )
                )
            ]
        )

        // When
        let image = try Builder().build([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image["app.reach"]?.failing == .these(["aborted"]))
        #expect(image[entryName]?.failing == .these(["aborted"]))
    }

    @Test("a plain cast is what the runtime itself may fail with")
    func aPlainCastFails() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .any)]),
                    body: [],
                    result: .cast(reference("it"), as: .int, optional: false)
                )
            ]
        )

        // When
        let image = try Builder().build([sut] + Module.standard, entry: entryName)

        // Then. The optional spelling reads the mismatch as null instead
        #expect(image[entryName]?.failing == .these(["cast_refused"]))
    }

    @Test("a rescue takes the body's failures off, and adds its own")
    func aRescueClearsWhatTheBodyRaises() throws {
        // Given. The body aborts, the rescue casts
        let sut = try Module(
            imports: ["std.control.abort"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .any)]),
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(body: [], result: .call(
                                    Call(receiver: .literal(.string("no")), selector: "std.control.abort")
                                )),
                                rescue: Block(
                                    body: [],
                                    result: .cast(reference("it"), as: .int, optional: false)
                                ),
                                failure: "tried"
                            )
                        )
                    ],
                    result: reference("tried")
                )
            ]
        )

        // When
        let image = try Builder().build([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image[entryName]?.failing == .these(["cast_refused"]))
    }

    @Test("a rescue over a body that cannot fail refuses")
    func aDeadRescueRefuses() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(body: [], result: .literal(.int(1))),
                                rescue: Block(body: [], result: .literal(.int(2))),
                                failure: "tried"
                            )
                        )
                    ],
                    result: reference("tried")
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("attempts a body that cannot fail")
        }
    }

    @Test("calling a value leaves the question open, so an attempt over one stands")
    func applyingAValueSaysNothing() throws {
        // Given. Which value is called is settled at run time
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["piece": Parameter(type: .procedure(nil))]
                    ),
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(body: [], result: .apply(reference("piece"), arguments: [:])),
                                rescue: Block(body: [], result: .literal(.int(2))),
                                failure: "tried"
                            )
                        )
                    ],
                    result: reference("tried")
                )
            ]
        )

        // When
        let image = try Builder().build([sut] + Module.standard, entry: entryName)

        // Then. The rescue caught an unknown, and what is left is the rescue's
        #expect(image[entryName]?.failing == .these([]))
    }

    // MARK: - Public
    // MARK: - Private
}

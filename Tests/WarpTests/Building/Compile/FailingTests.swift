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

// What a body may fail with, before it runs. A declaration says what may come
// out of it, and a body is held to that by what it casts, calls and catches,
// every callee read by its own declaration, so the build can tell an author a
// body fails beyond what it says and that a catch is a body no run reaches.
@Suite("What may come out of a body")
struct FailingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body that casts and calls nothing that fails declares no failure")
    func aQuietBodyFailsNothing() async throws {
        // Given. `plus` throws only at an author mistake, so it fails nothing
        let sut = try Module(
            imports: ["Standard.Numeric.plus"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        returning(.call(
                            Call(selector: "Standard.Numeric.plus", arguments: [.literal(.int(1)), .literal(.int(2))])
                        ))
                    ]
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image[entryName]?.signature.failing == .these([]))
    }

    @Test("a body calling a procedure that raises declares what it raises")
    func aRaisingProcedureIsDeclaredByItsCallers() async throws {
        // Given
        let sut = reaching(failing: .these(["aborted"]))

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image[entryName]?.signature.failing == .these(["aborted"]))
    }

    @Test("a body failing beyond what its declaration says refuses")
    func aBodyFailingBeyondItsDeclarationRefuses() async throws {
        // Given. `App.reach` may fail with `aborted`, and the entry says nothing
        let sut = reaching(failing: .these([]))

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("may fail with 'aborted', and its declaration says nothing")
        }
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
                    signature: Signature(parameters: [Parameter(name: "it", type: .any)], failing: .these(["aborted"])),
                    body: [returning(.call(Call(selector: "Standard.Control.abort", arguments: [reference("it")])))]
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
        // Given. The optional spelling reads the mismatch as null instead
        let casting = { (failing: Failing) in
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(parameters: [Parameter(name: "it", type: .any)], returns: .int, failing: failing),
                        body: [returning(.cast(reference("it"), as: .int, optional: false))]
                    )
                ]
            )
        }

        // When
        let image = try await Builder().build([try casting(.these(["cast_refused"]))] + Module.standard)

        // Then
        #expect(image[entryName]?.signature.failing == .these(["cast_refused"]))
        await #expect(throws: BuildError.self) {
            try await Builder().build([try casting(.these([]))] + Module.standard)
        }
    }

    @Test("a catch takes the body's failures off, and adds its own")
    func aCatchClearsWhatTheBodyRaises() async throws {
        // Given. The body aborts, the catch casts, and the declaration names
        // what the catch may fail with alone
        let sut = try Module(
            imports: ["Standard.Control.abort"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "it", type: .any)],
                        returns: .int,
                        failing: .these(["cast_refused"])
                    ),
                    body: [
                        Statement(binding: .variable("tried"), expression: .literal(.null)),
                        Statement(
                            expression: .try(
                                [
                                    Statement(expression: .call(
                                        Call(selector: "Standard.Control.abort", arguments: [.literal(.string("no"))])
                                    ))
                                ],
                                catch: [
                                    Statement(binding: .assignment([.name("tried")]), expression: .cast(reference("it"), as: .int, optional: false))
                                ]
                            )
                        ),
                        returning(reference("tried"))
                    ]
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        #expect(image[entryName]?.signature.failing == .these(["cast_refused"]))
    }

    @Test("a catch over a body that cannot fail refuses")
    func aDeadCatchRefuses() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .variable("tried"), expression: .literal(.null)),
                        Statement(
                            expression: .try(
                                [Statement(binding: .assignment([.name("tried")]), expression: .literal(.int(1)))],
                                catch: [Statement(binding: .assignment([.name("tried")]), expression: .literal(.int(2)))]
                            )
                        ),
                        returning(reference("tried"))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("tries a body that cannot fail")
        }
    }

    @Test("calling a value leaves the question open, so a try over one stands")
    func applyingAValueSaysNothing() async throws {
        // Given. Which value is called is decided at run time
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "piece", type: .procedure(ProcedureType(returns: .int, failing: .anything)))],
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .variable("tried"), expression: .literal(.null)),
                        Statement(
                            expression: .try(
                                [Statement(binding: .assignment([.name("tried")]), expression: .apply(reference("piece"), arguments: []))],
                                catch: [Statement(binding: .assignment([.name("tried")]), expression: .literal(.int(2)))]
                            )
                        ),
                        returning(reference("tried"))
                    ]
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then. The catch caught an unknown, and what is left is the catch's
        #expect(image[entryName]?.signature.failing == .these([]))
    }

    // MARK: - Public
    // MARK: - Private
    // An entry calling `App.reach`, which aborts and says so, the entry
    // declaring `failing`.
    private func reaching(failing: Failing) -> Module {
        try! Module(
            imports: ["Standard.Control.abort"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .never, failing: failing),
                    body: [returning(.call(Call(selector: "App.reach")))]
                ),
                "App.reach": Procedure(
                    signature: Signature(returns: .never, failing: .these(["aborted"])),
                    body: [
                        returning(.call(
                            Call(selector: "Standard.Control.abort", arguments: [.literal(.string("no"))])
                        ))
                    ]
                )
            ]
        )
    }
}

//
//  LinearTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// A value handed on exactly once. What the type says is that the values of it
// are given away: to a procedure, or as the body's answer. What the build proves is
// that every way through a body does that once, which is what "this resource
// is closed exactly once" comes to.
@Suite("A value handed on once")
struct LinearTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a body that opens and closes stands")
    func openedAndClosed() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect(throws: Never.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a body that opens and does not close refuses")
    func openedAndDropped() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open")))
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("still holds 'handle' where it ends")
        }
    }

    @Test("a body that closes twice refuses")
    func closedTwice() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null)
        )

        // When / Then. The second send reads a name that holds nothing, which
        // is what the reading walk calls it before this one is asked
        #expect(throws: BuildError.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("closing in one arm and not the other refuses")
    func closedInOneArm() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    expression: .conditional(
                        .literal(.bool(true)),
                        then: [
                            Statement(
                                expression: .call(Call(receiver: reference("handle"), selector: "app.close"))
                            )
                        ],
                        else: nil
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("in one arm and not in the other")
        }
    }

    @Test("closing inside a loop refuses, since a round runs no fixed number of times")
    func closedInsideALoop() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    expression: .loop(
                        while: .literal(.bool(false)),
                        body: Block(
                            body: [
                                Statement(
                                    expression: .call(Call(receiver: reference("handle"), selector: "app.close"))
                                )
                            ]
                        ),
                        round: "spin"
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("inside a loop, which happens no fixed number of times")
        }
    }

    @Test("handing it to a slot that does not say once refuses")
    func handedToAPlainSlot() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    expression: .call(Call(selector: "app.peek", arguments: ["at": reference("handle")]))
                ),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("does not take a value written `linear`")
        }
    }

    @Test("a body may hand it on by answering it, and its caller then owes it")
    func handedOnByAnswering() throws {
        // Given. `app.borrow` answers the handle, so the entry owes it
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.borrow"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.borrow": Procedure(
                    signature: Signature(returns: .named("app.Handle")),
                    body: [],
                    result: .call(Call(selector: "app.open"))
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("`linear` is written on a type and not on a slot")
    func onceOutsideATypeRefuses() throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .linear(.int))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("only a declared type is handed on once")
        }
    }

    @Test("a value handed on once is not carried inside another type")
    func onceInsideAnotherTypeRefuses() throws {
        // Given. Nothing follows a value into a list, so nothing could say the
        // list handed each of them on
        let sut = try Module(
            types: [
                "app.Handle": .linear(.record(["name": .string])),
                "app.Batch": .record(["held": .array(.named("app.Handle"))])
            ],
            procedures: [entryName: Procedure(body: [], result: .literal(.null))]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("carries 'app.Handle' inside another type")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A handle that must be closed, a procedure that makes one, a procedure that takes
    // one, and a procedure that only looks.
    private func holding(
        body: [Statement],
        result: Warp.Expression,
        beside others: [Name: Procedure] = [:]
    ) throws -> Module {
        try Module(
            types: ["app.Handle": .linear(.record(["name": .string]))],
            procedures: [
                entryName: Procedure(body: body, result: result),
                "app.open": Procedure(
                    signature: Signature(returns: .named("app.Handle")),
                    body: [],
                    result: .cast(
                        .record(["name": .literal(.string("f"))]),
                        as: .named("app.Handle"),
                        optional: false
                    )
                ),
                "app.close": Procedure(
                    signature: Signature(of: CloseEffect.self, receiver: .of),
                    implementation: .effect(CloseEffect())
                ),
                "app.peek": Procedure(
                    signature: Signature(parameters: ["at": Parameter(type: .any)]),
                    body: [],
                    result: .literal(.null)
                )
            ].merging(others) { _, added in added }
        )
    }
}

struct CloseEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .named("app.Handle")) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        .null
    }

    // MARK: - Private
}

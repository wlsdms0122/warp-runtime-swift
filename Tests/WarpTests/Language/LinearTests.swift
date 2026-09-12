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

    @Test("handing it to a slot that says neither refuses")
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
            "\(error)".contains("says nothing about what it does with a value written `linear`")
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

    @Test("a body may read what it borrowed and still owes nothing")
    func borrowedIsReadAndNotOwed() throws {
        // Given. `app.name` borrows, so the caller still holds the handle
        // afterwards and closes it itself
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(receiver: reference("handle"), selector: "app.name"))
                ),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: reference("shown")
        )

        // When / Then
        #expect(throws: Never.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a borrowing slot does not end the obligation")
    func borrowingIsNotClosing() throws {
        // Given. Only `app.name` is called, so the handle is still held at the end
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(receiver: reference("handle"), selector: "app.name"))
                )
            ],
            result: reference("shown")
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("still holds 'handle' where it ends")
        }
    }

    @Test("a body cannot hand on what it only borrowed")
    func borrowedIsNotHandedOn() throws {
        // Given. `app.give` borrows and then closes what it was lent
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.give"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.give": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .borrowing(.named("app.Handle")))]
                    ),
                    body: [
                        Statement(expression: .call(Call(receiver: reference("of"), selector: "app.close")))
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("borrowed 'of' rather than taking it")
        }
    }

    @Test("a body cannot answer what it only borrowed")
    func borrowedIsNotAnswered() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.leak": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .borrowing(.named("app.Handle")))],
                        returns: .named("app.Handle")
                    ),
                    body: [],
                    result: reference("of")
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("answers 'of', and it borrowed 'of' rather than taking it")
        }
    }

    @Test("a body cannot keep what it only borrowed in a box")
    func borrowedIsNotKept() throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.stash": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .borrowing(.named("app.Handle")))]
                    ),
                    body: [
                        Statement(binding: .variable("kept"), expression: reference("of"))
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("keeps 'of' in a box")
        }
    }

    @Test("a slot says neither about a type nothing is handed on once for")
    func aMarkWhereNothingIsOwedRefuses() throws {
        // Given. `consuming int` claims something about an obligation no value
        // of the type carries
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.count": Procedure(
                    signature: Signature(parameters: ["of": Parameter(type: .consuming(.int))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("Nothing here is handed on once")
        }
    }

    @Test("inout is not one of the two things a slot may say about it")
    func inoutIsNotAConvention() throws {
        // Given. Writing in place and taking the obligation are two different
        // things, and a slot that said both would leave what it holds
        // afterwards undecided
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.swap": Procedure(
                    signature: Signature(
                        parameters: ["of": Parameter(type: .inout(.named("app.Handle")))]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("says nothing about what it does with it")
        }
    }

    @Test("a parameter naming a type handed on once says what it does with it")
    func aSilentSlotRefuses() throws {
        // Given. `app.take` names the type and says nothing, which used to read
        // as taking the obligation and is what hid borrowing
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.take": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .named("app.Handle"))]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("says nothing about what it does with it")
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
                ),
                // Reads the handle and leaves the obligation with the caller.
                "app.name": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .borrowing(.named("app.Handle")))],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("name")])
                )
            ].merging(others) { _, added in added }
        )
    }
}

struct CloseEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .consuming(.named("app.Handle"))) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        .null
    }

    // MARK: - Private
}

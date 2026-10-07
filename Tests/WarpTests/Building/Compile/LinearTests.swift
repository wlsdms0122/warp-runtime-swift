//
//  LinearTests.swift
//  WarpTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// Values of a type written `linear`, and the build's proof that every way
// through a body hands each one on exactly once: to a procedure, or as the
// body's answer.
@Suite("A value handed on once")
struct LinearTests {
    struct CloseEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .consuming(.named("App.Handle"))) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) throws -> Value {
            .null
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a body that opens and closes stands")
    func openedAndClosed() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a body that opens and does not close refuses")
    func openedAndDropped() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open")))
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("still holds 'handle' where it ends")
        }
    }

    @Test("a body that closes twice refuses")
    func closedTwice() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")]))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("hands 'handle' on a second time")
        }
    }

    @Test("closing in one arm and not the other refuses")
    func closedInOneArm() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    expression: .conditional(
                        .literal(.bool(true)),
                        then: [
                            Statement(
                                expression: .call(Call(selector: "App.close", arguments: [reference("handle")]))
                            )
                        ],
                        else: nil
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("in one arm and not in the other")
        }
    }

    @Test("closing inside a loop refuses, since a round runs no fixed number of times")
    func closedInsideALoop() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    expression: .loop(
                        while: .literal(.bool(false)),
                        body: Block(
                            body: [
                                Statement(
                                    expression: .call(Call(selector: "App.close", arguments: [reference("handle")]))
                                )
                            ]
                        )
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("inside a loop, which happens no fixed number of times")
        }
    }

    @Test("handing it to a slot that says neither refuses")
    func handedToAPlainSlot() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    expression: .call(Call(selector: "App.peek", arguments: [reference("handle")]))
                ),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("says nothing about what it does with a value written `linear`")
        }
    }

    @Test("a body may hand it on by answering it, and its caller then owes it")
    func handedOnByAnswering() async throws {
        // Given. `App.borrow` answers the handle, so the entry owes it
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.borrow"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.borrow": Procedure(
                    signature: Signature(returns: .named("App.Handle")),
                    body: [],
                    result: .call(Call(selector: "App.open"))
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("`linear` is written on a type and not on a slot")
    func linearOutsideATypeRefuses() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .linear(.int))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("only a declared type is handed on once")
        }
    }

    @Test("a value handed on once is not carried inside another type")
    func linearInsideAnotherTypeRefuses() async throws {
        // Given. Nothing follows a value into a list, so nothing could say the
        // list handed each of them on
        let sut = try Module(
            types: [
                "App.Handle": .linear(.record(["name": .string])),
                "App.Batch": .record(["held": .array(.named("App.Handle"))])
            ],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries 'App.Handle' inside another type")
        }
    }

    @Test("a body may read what it borrowed and still owes nothing")
    func borrowedIsReadAndNotOwed() async throws {
        // Given. `App.name` borrows, so the caller still holds the handle
        // afterwards and closes it itself
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(selector: "App.name", arguments: [reference("handle")]))
                ),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: reference("shown")
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a borrowing slot does not end the obligation")
    func borrowingIsNotClosing() async throws {
        // Given. Only `App.name` is called, so the handle is still held at the end
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(selector: "App.name", arguments: [reference("handle")]))
                )
            ],
            result: reference("shown")
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("still holds 'handle' where it ends")
        }
    }

    @Test("a body cannot hand on what it only borrowed")
    func borrowedIsNotHandedOn() async throws {
        // Given. `App.give` borrows and then closes what it was lent
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.give", arguments: [reference("handle")]))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.give": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))]
                    ),
                    body: [
                        Statement(expression: .call(Call(selector: "App.close", arguments: [reference("of")])))
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("borrowed 'of' rather than taking it")
        }
    }

    @Test("a body cannot answer what it only borrowed")
    func borrowedIsNotAnswered() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.leak": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))],
                        returns: .named("App.Handle")
                    ),
                    body: [],
                    result: reference("of")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("answers 'of', and it borrowed 'of' rather than taking it")
        }
    }

    @Test("a body cannot keep what it only borrowed in a box")
    func borrowedIsNotKept() async throws {
        // Given
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.stash": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))]
                    ),
                    body: [
                        Statement(binding: .variable("kept"), expression: reference("of"))
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("keeps 'of' in a box")
        }
    }

    @Test("a slot says neither about a type nothing is handed on once for")
    func aMarkWhereNothingIsOwedRefuses() async throws {
        // Given. `consuming Int` claims something about an obligation no value
        // of the type carries
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.count": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .consuming(.int))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("No value of the type written here is")
        }
    }

    @Test("inout is not one of the two things a slot may say about it")
    func inoutIsNotAConvention() async throws {
        // Given. `App.swap` writes `inout` on the type and neither mark
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.swap": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .inout(.named("App.Handle")))]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("says nothing about what it does with it")
        }
    }

    @Test("a conditional in the body does not forget what was borrowed")
    func aConditionalKeepsTheBorrow() async throws {
        // Given. `App.leak` answers what it borrowed after a conditional
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.leak": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))],
                        returns: .named("App.Handle")
                    ),
                    body: [
                        Statement(
                            binding: .none,
                            expression: .conditional(.literal(.bool(true)), then: [], else: [])
                        )
                    ],
                    result: reference("of")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("answers 'of', and it borrowed 'of' rather than taking it")
        }
    }

    @Test("a name already handed on is not read through a slot that borrows")
    func aHandedOnNameIsNotLent() async throws {
        // Given. Reading a closed handle is what the whole rule is for, and a
        // slot that only borrows is still a slot that reads it
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")]))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(selector: "App.name", arguments: [reference("handle")]))
                )
            ],
            result: reference("shown")
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("hands 'handle' on a second time")
        }
    }

    @Test("a closure does not capture what was borrowed")
    func aClosureDoesNotCaptureABorrow() async throws {
        // Given. `App.stash` answers a closure that reads a part of what it
        // borrowed
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.stash": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))],
                        returns: .procedure(ProcedureType(returns: .string))
                    ),
                    body: [],
                    result: .closure(
                        Procedure(
                            signature: Signature(returns: .string),
                            body: [],
                            result: .reference([.key("of"), .key("name")])
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("captures 'of' in a closure, and it borrowed 'of'")
        }
    }

    @Test("a borrow does not leave inside a list or a record")
    func aBorrowDoesNotLeaveInsideAType() async throws {
        // Given. Wrapping the name is not reading a part of it: the whole value
        // goes into the list, and what a body borrowed it may not give away
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.leak": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))],
                        returns: .any
                    ),
                    body: [],
                    result: .array([reference("of")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries 'of' inside a list or a record")
        }
    }

    @Test("an obligation does not leave inside a list or a record")
    func anObligationDoesNotLeaveInsideAType() async throws {
        // Given. The walk follows names, and a name does not go into a type, so
        // the obligation would neither be handed on nor still be held
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open")))
            ],
            result: .array([reference("handle")])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries 'handle' inside a list or a record")
        }
    }

    @Test("a value handed on once does not reach a list without a name, either")
    func aFreshObligationDoesNotReachAList() async throws {
        // Given. The name check is not enough: nothing holds this one yet, and
        // writing it straight into the list is the same loss
        let sut = try holding(body: [], result: .array([.call(Call(selector: "App.open"))]))

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("writes what 'App.open' answers inside a list or a record")
        }
    }

    @Test("a block answers what its result answers, into a list as anywhere else")
    func aBlockIntoAListIsJudgedByItsResult() async throws {
        // Given. An element that is a block hands out whatever its result hands
        // out, so the element is judged by that rather than by its own shape
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open")))
            ],
            result: .array([.block(Block(body: [], result: reference("handle")))])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries 'handle' inside a list or a record")
        }
    }

    @Test("a block that answers one binds the obligation to the name it is bound to")
    func aBlockAnswersAnObligation() async throws {
        // Given. `held` takes the obligation the block's result answers, so a
        // body that never hands it on is refused for holding it
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .block(Block(body: [], result: .call(Call(selector: "App.open"))))
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("still holds 'held' where it ends")
        }
    }

    @Test("a cast does not carry one into a list either")
    func aCastDoesNotCarryOneIntoAList() async throws {
        // Given. A cast answers what it read, so the element is judged by that
        // rather than by the cast's own shape
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open")))
            ],
            result: .array([.cast(reference("handle"), as: .named("App.Openable"), optional: false)]),
            constraints: ["App.Openable": [.named("App.Handle")]]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries 'handle' inside a list or a record")
        }
    }

    @Test("a name already given away is refused for that, not for the list it was written into")
    func aGoneNameInAListSaysWhyItIsGone() async throws {
        // Given. The advice "bind it to a name and hand it on from there" has
        // nowhere to land when the name already handed it on once
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .array([reference("handle")])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("hands 'handle' on a second time")
        }
    }

    @Test("a membership every member of which is handed on once is one")
    func anAllLinearMembershipCarriesTheObligation() async throws {
        // Given. A body binding what such a procedure answers takes the
        // obligation, and dropping it is refused like any other
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make")))
            ],
            result: .literal(.null),
            constraints: ["App.Openable": [.named("App.Handle")]],
            beside: [
                "App.make": Procedure(
                    signature: Signature(returns: .named("App.Openable")),
                    body: [],
                    result: .call(Call(selector: "App.open"))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("still holds 'held' where it ends")
        }
    }

    @Test("a membership that mixes one with something else refuses")
    func aMixedMembershipRefuses() async throws {
        // Given. A value of it would carry an obligation on some readings and
        // not on others, and which it was is what a membership does not say
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            constraints: ["App.Openable": [.named("App.Handle"), .int]]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("beside Int, which is not")
        }
    }

    @Test("a cast that names one does not carry it into a list")
    func aCastNamingOneDoesNotCarryIt() async throws {
        // Given. Nothing inside the cast holds an obligation, and the cast
        // itself is what says the value is one, so the element is asked of the
        // cast as well as of what it read
        let sut = try holding(
            body: [],
            result: .array([
                .cast(
                    .record(["name": .literal(.string("f"))]),
                    as: .named("App.Handle"),
                    optional: false
                )
            ])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("writes what this reads as 'App.Handle' inside a list")
        }
    }

    @Test("two memberships that name each other are all of one thing or not")
    func aRingOfMembershipsAnswersAsItStood() async throws {
        // Given. `App.A` and `App.B` name each other, and every other member of
        // either is `App.Handle`
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            constraints: [
                "App.A": [.named("App.Handle"), .named("App.B")],
                "App.B": [.named("App.Handle"), .named("App.A")]
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a cast that may answer nothing does not take one")
    func anOptionalCastRefuses() async throws {
        // Given. `payload` is read as `App.Handle` with `as?`
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .cast(reference("payload"), as: .named("App.Handle"), optional: true)
                )
            ],
            result: .literal(.null),
            taking: [Parameter(name: "payload", type: .any)]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("is handed on exactly once, and may answer nothing")
        }
    }

    @Test("a return is a way out of a body too")
    func aReturnAnswersLikeAResult() async throws {
        // Given. What a declaration answers is the join of its result and every
        // `return` that carries a value, so the rule that holds one holds the
        // other
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make")))
            ],
            result: .literal(.null),
            beside: [
                "App.make": Procedure(
                    signature: Signature(),
                    body: [
                        Statement(
                            binding: .none,
                            expression: .conditional(
                                .literal(.bool(true)),
                                then: [
                                    Statement(
                                        binding: .none,
                                        expression: .leave(
                                            Leave(
                                                reach: .procedure,
                                                value: .call(Call(selector: "App.open"))
                                            )
                                        )
                                    )
                                ],
                                else: nil
                            )
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("a return of a bare name is a way out too")
    func aReturnOfABareNameAnswers() async throws {
        // Given. The name is gone by the time the walk has moved it, which is
        // the same moment the result is asked, so both doors answer the same
        // question at the same time
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make")))
            ],
            result: .literal(.null),
            beside: [
                "App.make": Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("own"), expression: .call(Call(selector: "App.open"))),
                        Statement(
                            binding: .none,
                            expression: .leave(Leave(reach: .procedure, value: reference("own")))
                        )
                    ],
                    result: nil
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("an attempt does not drop what a body already handed out")
    func anAttemptKeepsWhatWasHandedOut() async throws {
        // Given. `App.make` returns one from inside the attempt's body and
        // writes no `returns`
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make")))
            ],
            result: .literal(.null),
            beside: [
                "App.make": Procedure(
                    signature: Signature(),
                    body: [
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(
                                    body: [
                                        mayFail(),
                                        Statement(
                                            binding: .none,
                                            expression: .leave(
                                                Leave(
                                                    reach: .procedure,
                                                    value: .call(Call(selector: "App.open"))
                                                )
                                            )
                                        )
                                    ]
                                ),
                                rescue: Block(body: [
                                    Statement(binding: .constant("seen"), expression: .literal(.int(1)))
                                ])
                            )
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("a body carried as a value does not answer one")
    func aCarriedBodyDoesNotAnswerOne() async throws {
        // Given. The closure writes `returns` naming `App.Handle`
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("made"),
                    expression: .closure(
                        Procedure(
                            signature: Signature(returns: .named("App.Handle")),
                            body: [],
                            result: .call(Call(selector: "App.open"))
                        )
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("writes a procedure answering App.Handle")
        }
    }

    @Test("a carried body that wrote no returns is read the same way")
    func aCarriedBodyWithoutReturnsIsRead() async throws {
        // Given. The rule cannot turn on whether a key was typed, so a closure
        // that wrote no `returns` is read by what it answers
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("made"),
                    expression: .closure(
                        Procedure(body: [], result: .call(Call(selector: "App.open")))
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries a body answering a value handed on exactly once")
        }
    }

    @Test("a carried body answers one through a name, and is read the same")
    func aCarriedBodyAnsweringThroughAName() async throws {
        // Given. The rule cannot turn on how the answer was written any more
        // than on whether a key was typed, so the body is walked rather than
        // read off its shape
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("made"),
                    expression: .closure(
                        Procedure(
                            body: [
                                Statement(
                                    binding: .constant("own"),
                                    expression: .call(Call(selector: "App.open"))
                                )
                            ],
                            result: reference("own")
                        )
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries a body answering a value handed on exactly once")
        }
    }

    @Test("a carried body one closure deeper is walked too")
    func aCarriedBodyOneClosureDeeper() async throws {
        // Given. The closure answering one stands inside another closure
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("outer"),
                    expression: .closure(
                        Procedure(
                            body: [
                                Statement(
                                    binding: .constant("inner"),
                                    expression: .closure(
                                        Procedure(body: [], result: .call(Call(selector: "App.open")))
                                    )
                                )
                            ],
                            result: .literal(.null)
                        )
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("carries a body answering a value handed on exactly once")
        }
    }

    @Test("a carried body that opens one and drops it is refused like any other")
    func aCarriedBodyDropsItsOwn() async throws {
        // Given. A closure is a procedure and its body is text, so the same
        // walk holds it to the same rule. What it runs an unfixed number of
        // times is the capture, and this name is its own
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("made"),
                    expression: .closure(
                        Procedure(
                            body: [
                                Statement(
                                    binding: .constant("own"),
                                    expression: .call(Call(selector: "App.open"))
                                )
                            ],
                            result: .literal(.null)
                        )
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("still holds 'own' where it ends")
        }
    }

    @Test("break leaves a loop, not the body that is still holding one")
    func breakDoesNotStrandWhatTheBodyHolds() async throws {
        // Given. Only leaving the procedure ends the body. What it was holding
        // it is holding still on the other side of the loop, and closes there
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    binding: .constant("spin"),
                    expression: .loop(
                        while: .literal(.bool(true)),
                        body: Block(
                            body: [
                                Statement(binding: .none, expression: .leave(Leave(reach: .construct)))
                            ]
                        )
                    )
                ),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("an arm that returns does not have to hold what the arms that finish hold")
    func anArmThatLeavesHoldsNothingAfterwards() async throws {
        // Given. Each way through hands the handle on exactly once: the way out
        // by answering it, the way on by closing it. No run comes back from the
        // arm that returns, so what it was holding is not what the body holds
        // afterwards
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("held")])))
            ],
            result: .literal(.null),
            beside: [
                "App.make": Procedure(
                    signature: Signature(returns: .named("App.Handle")),
                    body: [
                        Statement(binding: .constant("own"), expression: .call(Call(selector: "App.open"))),
                        Statement(
                            binding: .none,
                            expression: .conditional(
                                .literal(.bool(true)),
                                then: [
                                    Statement(
                                        binding: .none,
                                        expression: .leave(Leave(reach: .procedure, value: reference("own")))
                                    )
                                ],
                                else: nil
                            )
                        ),
                        Statement(expression: .call(Call(selector: "App.close", arguments: [reference("own")]))),
                        Statement(
                            binding: .none,
                            expression: .leave(
                                Leave(reach: .procedure, value: .call(Call(selector: "App.open")))
                            )
                        )
                    ],
                    result: nil
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("an arm that leaves is still holding nothing when it leaves")
    func anArmThatLeavesIsStillJudged() async throws {
        // Given. Contributing nothing afterwards is not being let off: the arm
        // answers a handle it does not hold and drops the one it does
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("held")])))
            ],
            result: .literal(.null),
            beside: [
                "App.make": Procedure(
                    signature: Signature(returns: .named("App.Handle")),
                    body: [
                        Statement(binding: .constant("own"), expression: .call(Call(selector: "App.open"))),
                        Statement(
                            binding: .none,
                            expression: .conditional(
                                .literal(.bool(true)),
                                then: [
                                    Statement(
                                        binding: .none,
                                        expression: .leave(
                                            Leave(
                                                reach: .procedure,
                                                value: .call(Call(selector: "App.open"))
                                            )
                                        )
                                    )
                                ],
                                else: nil
                            )
                        ),
                        Statement(expression: .call(Call(selector: "App.close", arguments: [reference("own")]))),
                        Statement(
                            binding: .none,
                            expression: .leave(
                                Leave(reach: .procedure, value: .call(Call(selector: "App.open")))
                            )
                        )
                    ],
                    result: nil
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("leaves while still holding 'own'")
        }
    }

    @Test("a break carries what the arm opened out of the loop, and it is still owed")
    func aBreakDoesNotExcuseTheArmItLeavesFrom() async throws {
        // Given. A run does come back from a `break`: it comes back out of the
        // loop still holding what the arm opened, so such an arm is judged the
        // way any other is
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("spin"),
                    expression: .loop(
                        while: .literal(.bool(true)),
                        body: Block(
                            body: [
                                Statement(
                                    binding: .none,
                                    expression: .conditional(
                                        .literal(.bool(true)),
                                        then: [
                                            Statement(
                                                binding: .constant("own"),
                                                expression: .call(Call(selector: "App.open"))
                                            ),
                                            Statement(
                                                binding: .none,
                                                expression: .leave(Leave(reach: .construct))
                                            )
                                        ],
                                        else: nil
                                    )
                                )
                            ]
                        )
                    )
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("in one arm and not in the other")
        }
    }

    @Test("an attempt ends the body only where its body and its rescue both do")
    func anAttemptEndsTheBodyWhereBothDo() async throws {
        // Given. One arm closes the handle and then ends the body inside an
        // attempt, and the arm beside it still holds the handle
        func body(rescueEnds: Bool) -> Body {
            let ending = Statement(
                binding: .none,
                expression: .leave(Leave(reach: .procedure, value: .literal(.null)))
            )

            return [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    binding: .none,
                    expression: .conditional(
                        .literal(.bool(true)),
                        then: [
                            Statement(
                                expression: .call(Call(selector: "App.close", arguments: [reference("handle")]))
                            ),
                            Statement(
                                binding: .none,
                                expression: .attempt(
                                    Block(body: [mayFail(), ending]),
                                    rescue: Block(
                                        body: rescueEnds
                                            ? [ending]
                                            : [
                                                Statement(
                                                    binding: .constant("seen"),
                                                    expression: .literal(.int(1))
                                                )
                                            ]
                                    )
                                )
                            )
                        ],
                        else: nil
                    )
                ),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ]
        }

        // When / Then. Where the rescue ends the body too, no run comes back
        // from the arm and the arm beside it says what is held
        await #expect(throws: Never.self) {
            try await Builder().build(
                [try holding(body: body(rescueEnds: true), result: .literal(.null))] + Module.standard
            )
        }

        // Where it does not, the arm comes back having handed the handle on
        // and the arm beside it has not
        await #expect {
            try await Builder().build(
                [try holding(body: body(rescueEnds: false), result: .literal(.null))] + Module.standard
            )
        } throws: { error in
            "\(error)".contains("in one arm and not in the other")
        }
    }

    @Test("a `?` does not stand on a type handed on once")
    func aNullableOfOneRefuses() async throws {
        // Given. The doubt and the mark say opposite things about the same
        // value, so a slot writing both says nothing a body could act on
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.maybe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .nullable(.named("App.Handle")))]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("writes `?` on App.Handle, which is handed on exactly once")
        }
    }

    @Test("a declaration whose body answers one writes what it answers")
    func anUnwrittenReturnsRefuses() async throws {
        // Given. What a declaration answers is read off its body where nobody
        // wrote `returns`, and the mark is not something a reading keeps, so
        // the caller would bind an obligation nothing told it about
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "App.make")))
            ],
            result: .literal(.null),
            beside: [
                "App.make": Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(selector: "App.open"))
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("an attempt answers what either way through it answers")
    func anAttemptIntoAListIsJudgedByBothWays() async throws {
        // Given. The reading of an attempt is the join of its body and its
        // rescue, so an element that is one hands out what either hands out
        let sut = try holding(
            body: [],
            result: .array([
                .attempt(
                    Block(body: [mayFail()], result: .call(Call(selector: "App.open"))),
                    rescue: Block(body: [], result: .call(Call(selector: "App.open")))
                )
            ])
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("inside a list or a record")
        }
    }

    @Test("a slot does not say what it does with a type parameter")
    func aTypeParameterTakesNoMark() async throws {
        // Given. `App.pass` writes `consuming` on `some T`
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.pass": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .consuming(.parameter(name: "T")))],
                        returns: .parameter(name: "T")
                    ),
                    body: [],
                    result: reference("of")
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("by naming the type that is one")
        }
    }

    @Test("a borrow passes on to another slot that borrows")
    func aBorrowPassesToAnotherBorrow() async throws {
        // Given. The one thing a borrowed name may be handed to. `App.show`
        // borrows and lends the same value on to `App.name`, which borrows too,
        // so the obligation never moves and the entry still closes it
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(selector: "App.show", arguments: [reference("handle")]))
                ),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: reference("shown"),
            beside: [
                "App.show": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(selector: "App.name", arguments: [reference("of")]))
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("borrowing inside a loop round stands, because nothing moves")
    func aBorrowInsideALoopStands() async throws {
        // Given. What a round runs an unfixed number of times is refused only
        // where something is handed on, and lending hands nothing on
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(
                    binding: .constant("spin"),
                    expression: .loop(
                        while: .literal(.bool(false)),
                        body: Block(
                            body: [
                                Statement(
                                    binding: .constant("shown"),
                                    expression: .call(
                                        Call(selector: "App.name", arguments: [reference("handle")])
                                    )
                                )
                            ]
                        )
                    )
                ),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null)
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a body cannot hand on what it borrowed from inside a loop round either")
    func aBorrowIsNotGivenAwayInsideALoop() async throws {
        // Given. The guard a round puts on handing something on does not
        // replace the one a borrow puts on giving it away at all
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.give": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))]
                    ),
                    body: [
                        Statement(
                            binding: .constant("spin"),
                            expression: .loop(
                                while: .literal(.bool(false)),
                                body: Block(
                                    body: [
                                        Statement(
                                            expression: .call(
                                                Call(selector: "App.close", arguments: [reference("of")])
                                            )
                                        )
                                    ]
                                )
                            )
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("borrowed 'of' rather than taking it")
        }
    }

    @Test("a parameter naming a type handed on once says what it does with it")
    func aSilentSlotRefuses() async throws {
        // Given. `App.take` names the type and writes neither mark
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "App.open"))),
                Statement(expression: .call(Call(selector: "App.close", arguments: [reference("handle")])))
            ],
            result: .literal(.null),
            beside: [
                "App.take": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("App.Handle"))]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("says nothing about what it does with it")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A linear handle, the entry, and procedures that make one (`App.open`),
    // take one (`App.close`), say neither (`App.peek`) and borrow one
    // (`App.name`).
    private func holding(
        body: Body,
        result: Warp.Expression,
        constraints: [Name: [TypeExpression]] = [:],
        taking parameters: [Parameter] = [],
        beside others: [Name: Procedure] = [:]
    ) throws -> Module {
        try Module(
            types: ["App.Handle": .linear(.record(["name": .string]))],
            constraints: constraints,
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: parameters),
                    body: body,
                    result: result
                ),
                "App.open": Procedure(
                    signature: Signature(returns: .named("App.Handle")),
                    body: [],
                    result: .cast(
                        .record(["name": .literal(.string("f"))]),
                        as: .named("App.Handle"),
                        optional: false
                    )
                ),
                "App.close": Procedure(
                    signature: Signature(of: CloseEffect.self),
                    implementation: .effect(CloseEffect())
                ),
                "App.peek": Procedure(
                    signature: Signature(parameters: [Parameter(name: "at", type: .any)]),
                    body: [],
                    result: .literal(.null)
                ),
                // Reads the handle and leaves the obligation with the caller.
                "App.name": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("name")])
                )
            ].merging(others) { _, added in added }
        )
    }
}

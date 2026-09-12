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
            "\(error)".contains("No value of the type written here is")
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

    @Test("a conditional in the body does not forget what was borrowed")
    func aConditionalKeepsTheBorrow() throws {
        // Given. Two ways through join what either made, and being borrowed is
        // one of those facts. A join that dropped it would let every borrow
        // rule go by writing an `if` first
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
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("answers 'of', and it borrowed 'of' rather than taking it")
        }
    }

    @Test("a name already handed on is not read through a slot that borrows")
    func aHandedOnNameIsNotLent() throws {
        // Given. Reading a closed handle is what the whole rule is for, and a
        // slot that only borrows is still a slot that reads it
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close"))),
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
            "\(error)".contains("hands 'handle' on a second time")
        }
    }

    @Test("a closure does not capture what was borrowed")
    func aClosureDoesNotCaptureABorrow() throws {
        // Given. This walk never enters a closure, so what a borrowed name does
        // in one is not something the text shows
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
                        parameters: ["of": Parameter(type: .borrowing(.named("app.Handle")))],
                        returns: .procedure(Signature(returns: .named("app.Handle")))
                    ),
                    body: [],
                    result: .closure(
                        Procedure(
                            signature: Signature(returns: .named("app.Handle")),
                            body: [],
                            result: reference("of")
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("captures 'of' in a closure, and it borrowed 'of'")
        }
    }

    @Test("a borrow does not leave inside a list or a record")
    func aBorrowDoesNotLeaveInsideAType() throws {
        // Given. Wrapping the name is not reading a part of it: the whole value
        // goes into the list, and what a body borrowed it may not give away
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
                        returns: .any
                    ),
                    body: [],
                    result: .array([reference("of")])
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("carries 'of' inside a list or a record")
        }
    }

    @Test("an obligation does not leave inside a list or a record")
    func anObligationDoesNotLeaveInsideAType() throws {
        // Given. The walk follows names, and a name does not go into a type, so
        // the obligation would neither be handed on nor still be held
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open")))
            ],
            result: .array([reference("handle")])
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("carries 'handle' inside a list or a record")
        }
    }

    @Test("a value handed on once does not reach a list without a name, either")
    func aFreshObligationDoesNotReachAList() throws {
        // Given. The name check is not enough: nothing holds this one yet, and
        // writing it straight into the list is the same loss
        let sut = try holding(body: [], result: .array([.call(Call(selector: "app.open"))]))

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("writes what 'app.open' answers inside a list or a record")
        }
    }

    @Test("a block answers what its result answers, into a list as anywhere else")
    func aBlockIntoAListIsJudgedByItsResult() throws {
        // Given. An element that is a block hands out whatever its result hands
        // out, so the element is judged by that rather than by its own shape
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open")))
            ],
            result: .array([.block(Block(body: [], result: reference("handle")))])
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("carries 'handle' inside a list or a record")
        }
    }

    @Test("a block that answers one binds the obligation to the name it is bound to")
    func aBlockAnswersAnObligation() throws {
        // Given. `held` takes the obligation the block's result answers, so a
        // body that never hands it on is refused for holding it
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .block(Block(body: [], result: .call(Call(selector: "app.open"))))
                )
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("still holds 'held' where it ends")
        }
    }

    @Test("a cast does not carry one into a list either")
    func aCastDoesNotCarryOneIntoAList() throws {
        // Given. A cast answers what it read, so the element is judged by that
        // rather than by the cast's own shape
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open")))
            ],
            result: .array([.cast(reference("handle"), as: .named("app.Openable"), optional: false)]),
            constraints: ["app.Openable": [.named("app.Handle")]]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("carries 'handle' inside a list or a record")
        }
    }

    @Test("a name already given away is refused for that, not for the list it was written into")
    func aGoneNameInAListSaysWhyItIsGone() throws {
        // Given. The advice "bind it to a name and hand it on from there" has
        // nowhere to land when the name already handed it on once
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .array([reference("handle")])
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("hands 'handle' on a second time")
        }
    }

    @Test("a membership every member of which is handed on once is one")
    func anAllLinearMembershipCarriesTheObligation() throws {
        // Given. A body binding what such a procedure answers takes the
        // obligation, and dropping it is refused like any other
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "app.make")))
            ],
            result: .literal(.null),
            constraints: ["app.Openable": [.named("app.Handle")]],
            beside: [
                "app.make": Procedure(
                    signature: Signature(returns: .named("app.Openable")),
                    body: [],
                    result: .call(Call(selector: "app.open"))
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("still holds 'held' where it ends")
        }
    }

    @Test("a membership that mixes one with something else refuses")
    func aMixedMembershipRefuses() throws {
        // Given. A value of it would carry an obligation on some readings and
        // not on others, and which it was is what a membership does not say
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            constraints: ["app.Openable": [.named("app.Handle"), .int]]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("beside int, which is not")
        }
    }

    @Test("a cast that names one does not carry it into a list")
    func aCastNamingOneDoesNotCarryIt() throws {
        // Given. Nothing inside the cast holds an obligation, and the cast
        // itself is what says the value is one, so the element is asked of the
        // cast as well as of what it read
        let sut = try holding(
            body: [],
            result: .array([
                .cast(
                    .record(["name": .literal(.string("f"))]),
                    as: .named("app.Handle"),
                    optional: false
                )
            ])
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("writes what this reads as 'app.Handle' inside a list")
        }
    }

    @Test("two memberships that name each other are all of one thing or not")
    func aRingOfMembershipsAnswersAsItStood() throws {
        // Given. Every leaf here is handed on once, and the ring between them
        // says nothing new. A ring answered as "not one" would make each of
        // these read as mixing one with something else, which is the opposite
        // of what they are
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            constraints: [
                "app.A": [.named("app.Handle"), .named("app.B")],
                "app.B": [.named("app.Handle"), .named("app.A")]
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a cast that may answer nothing does not take one")
    func anOptionalCastRefuses() throws {
        // Given. What a value handed on once needs is a name that holds it on
        // every way through, and a `?` says there is a way through where
        // nothing is there. The mark and the doubt are refused together
        let sut = try holding(
            body: [
                Statement(
                    binding: .constant("held"),
                    expression: .cast(reference("payload"), as: .named("app.Handle"), optional: true)
                )
            ],
            result: .literal(.null),
            taking: ["payload": Parameter(type: .any)]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("is handed on exactly once, and may answer nothing")
        }
    }

    @Test("a return is a way out of a body too")
    func aReturnAnswersLikeAResult() throws {
        // Given. What a declaration answers is the join of its result and every
        // `return` that carries a value, so the rule that holds one holds the
        // other
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "app.make")))
            ],
            result: .literal(.null),
            beside: [
                "app.make": Procedure(
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
                                                value: .call(Call(selector: "app.open"))
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
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("a return of a bare name is a way out too")
    func aReturnOfABareNameAnswers() throws {
        // Given. The name is gone by the time the walk has moved it, which is
        // the same moment the result is asked, so both doors answer the same
        // question at the same time
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "app.make")))
            ],
            result: .literal(.null),
            beside: [
                "app.make": Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("own"), expression: .call(Call(selector: "app.open"))),
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
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("an attempt does not drop what a body already handed out")
    func anAttemptKeepsWhatWasHandedOut() throws {
        // Given. What a body still holds dies with a way through that dies, and
        // an attempt drops its body's way. What it has already handed out is
        // not that kind of fact and does not die with it
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "app.make")))
            ],
            result: .literal(.null),
            beside: [
                "app.make": Procedure(
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
                                                    value: .call(Call(selector: "app.open"))
                                                )
                                            )
                                        )
                                    ]
                                ),
                                rescue: Block(body: [
                                    Statement(binding: .constant("seen"), expression: .literal(.int(1)))
                                ]),
                                failure: "why"
                            )
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("a `?` does not stand on a type handed on once")
    func aNullableOfOneRefuses() throws {
        // Given. The doubt and the mark say opposite things about the same
        // value, so a slot writing both says nothing a body could act on
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.maybe": Procedure(
                    signature: Signature(
                        parameters: ["of": Parameter(type: .nullable(.named("app.Handle")))]
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
            "\(error)".contains("writes `?` on app.Handle, which is handed on exactly once")
        }
    }

    @Test("a declaration whose body answers one writes what it answers")
    func anUnwrittenReturnsRefuses() throws {
        // Given. What a declaration answers is read off its body where nobody
        // wrote `returns`, and the mark is not something a reading keeps, so
        // the caller would bind an obligation nothing told it about
        let sut = try holding(
            body: [
                Statement(binding: .constant("held"), expression: .call(Call(selector: "app.make")))
            ],
            result: .literal(.null),
            beside: [
                "app.make": Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(selector: "app.open"))
                )
            ]
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("does not write `returns`")
        }
    }

    @Test("an attempt answers what either way through it answers")
    func anAttemptIntoAListIsJudgedByBothWays() throws {
        // Given. The reading of an attempt is the join of its body and its
        // rescue, so an element that is one hands out what either hands out
        let sut = try holding(
            body: [],
            result: .array([
                .attempt(
                    Block(body: [mayFail()], result: .call(Call(selector: "app.open"))),
                    rescue: Block(body: [], result: .call(Call(selector: "app.open"))),
                    failure: "tried"
                )
            ])
        )

        // When / Then
        #expect {
            try Builder().build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("inside a list or a record")
        }
    }

    @Test("a slot does not say what it does with a type parameter")
    func aTypeParameterTakesNoMark() throws {
        // Given. What fills `some T` is the call's, so after this slot took the
        // obligation there is no name for the build to follow it by: what the
        // call answers is read off the declaration, and the declaration says
        // `some T`. The proof would end here
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null),
            beside: [
                "app.pass": Procedure(
                    signature: Signature(
                        parameters: ["of": Parameter(type: .consuming(.parameter(name: "T")))],
                        returns: .parameter(name: "T")
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
            "\(error)".contains("by naming the type that is one")
        }
    }

    @Test("a borrow passes on to another slot that borrows")
    func aBorrowPassesToAnotherBorrow() throws {
        // Given. The one thing a borrowed name may be handed to. `app.show`
        // borrows and lends the same value on to `app.name`, which borrows too,
        // so the obligation never moves and the entry still closes it
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    binding: .constant("shown"),
                    expression: .call(Call(receiver: reference("handle"), selector: "app.show"))
                ),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: reference("shown"),
            beside: [
                "app.show": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["of": Parameter(type: .borrowing(.named("app.Handle")))],
                        returns: .string
                    ),
                    body: [],
                    result: .call(Call(receiver: reference("of"), selector: "app.name"))
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("borrowing inside a loop round stands, because nothing moves")
    func aBorrowInsideALoopStands() throws {
        // Given. What a round runs an unfixed number of times is refused only
        // where something is handed on, and lending hands nothing on
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
                Statement(
                    binding: .constant("spin"),
                    expression: .loop(
                        while: .literal(.bool(false)),
                        body: Block(
                            body: [
                                Statement(
                                    binding: .constant("shown"),
                                    expression: .call(
                                        Call(receiver: reference("handle"), selector: "app.name")
                                    )
                                )
                            ]
                        ),
                        round: "round"
                    )
                ),
                Statement(expression: .call(Call(receiver: reference("handle"), selector: "app.close")))
            ],
            result: .literal(.null)
        )

        // When / Then
        #expect(throws: Never.self) {
            try Builder().build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a body cannot hand on what it borrowed from inside a loop round either")
    func aBorrowIsNotGivenAwayInsideALoop() throws {
        // Given. The guard a round puts on handing something on does not
        // replace the one a borrow puts on giving it away at all
        let sut = try holding(
            body: [
                Statement(binding: .constant("handle"), expression: .call(Call(selector: "app.open"))),
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
                        Statement(
                            binding: .constant("spin"),
                            expression: .loop(
                                while: .literal(.bool(false)),
                                body: Block(
                                    body: [
                                        Statement(
                                            expression: .call(
                                                Call(receiver: reference("of"), selector: "app.close")
                                            )
                                        )
                                    ]
                                ),
                                round: "round"
                            )
                        )
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
        constraints: [Name: [TypeExpression]] = [:],
        taking parameters: [Name: Parameter] = [:],
        beside others: [Name: Procedure] = [:]
    ) throws -> Module {
        try Module(
            types: ["app.Handle": .linear(.record(["name": .string]))],
            constraints: constraints,
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: parameters),
                    body: body,
                    result: result
                ),
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

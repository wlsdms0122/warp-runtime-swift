//
//  NeverTests.swift
//  WarpTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
@testable import Warp

// A statement typed `never` does not finish, so it binds nothing and nothing
// after it runs. The syntactic leaves are refused where they are read; a call
// is the build's to refuse, because only the build knows what the procedure declares.
@Suite("What never finishes binds nothing")
struct NeverTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a block's leave judgment is true of the block alone")
    func alwaysLeavesIsTrueOfTheBlockAlone() {
        // Given. A block no validator has seen: the property answers from the
        // block itself, so a leaving body counts whatever the result declares,
        // and wherever in the body the leave sits
        let leave = Expression.leave(Leave(reach: .procedure, value: .literal(.int(1))))

        #expect(Block(body: [Statement(expression: leave)], result: .literal(.int(2))).alwaysLeaves)
        #expect(Block(
            body: [Statement(expression: leave), Statement(binding: .constant("after"), expression: .literal(.int(3)))]
        ).alwaysLeaves)
        #expect(!Block(body: [], result: .literal(.int(1))).alwaysLeaves)
    }

    @Test("a statement after a call that never finishes is refused at the build")
    func nothingRunsAfterANeverCall() async throws {
        // Given. `std.control.abort` declares never, so the statement after it
        // would never run, and a name written there would never bind
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(expression: refusing(literal("done"))),
                        Statement(binding: .constant("after"), expression: .literal(.int(1)))
                    ],
                    result: .reference([.key("after")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("what follows it here would never run")
        }
    }

    @Test("a name on the last statement is still refused when it never finishes")
    func aNamedNeverLastStatementIsRefused() async throws {
        // Given. Last in the body, so the "nothing after" rule has nothing to
        // say; only the name itself is wrong
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("gone"), expression: refusing(literal("done")))
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("binds nothing and takes no name")
        }
    }

    @Test("a loop's result reads at the exits, not a round further in")
    func aLoopResultReadsAtTheExits() async throws {
        // Given. The run may take any exit: a condition that declines at the
        // start answers before a single round wrote anything. So the result
        // reads in the settled join of the exits (`x` holds int or string, not
        // the one a finished round would prove) and a slot the 0-round value
        // fits is not refused on the round's account
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [
                    Statement(binding: .assignment([.key("x")]), expression: .literal(.string("s")))
                ],
                result: reference("x")
            ),
            round: "round"
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("x"), expression: .literal(.int(1))),
                        Statement(binding: .constant("kept"), expression: loop),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("kept")])]
                        ))
                        )
                    ],
                    result: reference("kept")
                ),
                "wants": Procedure(
                    signature: Signature(parameters: [Parameter(name: "count", type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then. Builds, and the run answers the 0-round value
        #expect(try await run([sut]) == .int(1))
    }

    @Test("a loop result's writes reach the names after the loop")
    func aLoopResultsWritesReachTheNamesAfter() async throws {
        // Given. The result runs on every exit, a 0-round run included, so a
        // write it makes lands whatever the rounds did: `y` after the loop may
        // hold what the result wrote, and a slot that fits that value is not
        // refused on the entry type's account
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [Statement(expression: refusing(literal("stops")))],
                result: .block(
                    Block(
                        body: [
                            Statement(binding: .assignment([.key("y")]), expression: .literal(.string("s"))
                            )
                        ],
                        result: reference("y")
                    )
                )
            ),
            round: "round"
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("y"), expression: .literal(.int(1))),
                        Statement(binding: .constant("kept"), expression: loop),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("y")])]
                        ))
                        )
                    ],
                    result: reference("y")
                ),
                "wants": Procedure(
                    signature: Signature(parameters: [Parameter(name: "text", type: .string)]),
                    body: []
                )
            ]
        )

        // When / Then. Builds, and the run answers what the result wrote
        #expect(try await run([sut]) == .string("s"))

        // And the write is definite (every exit made it) so `y` reads as
        // exactly what the result wrote, and an int slot refuses it
        let refusing = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("y"), expression: .literal(.int(1))),
                        Statement(binding: .constant("kept"), expression: loop),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("y")])]
                        ))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(parameters: [Parameter(name: "count", type: .int)]),
                    body: []
                )
            ]
        )

        await #expect {
            try await Builder().build([refusing] + Module.standard)
        } throws: { error in
            "\(error)".contains("holds string")
        }
    }

    @Test("a body that ends by leaving still carries its folded constant")
    func aLeavingBodyKeepsItsFolding() async throws {
        // Given. The image holds only judged spellings, and a body whose last
        // statement leaves is still a body the image holds: the constant it
        // carries out folds like any other
        let sut = try Module(
            constants: ["C": .literal(.int(7))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            expression: .leave(
                                Leave(reach: .procedure, value: .reference([.key("C")]))
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(7))
    }

    @Test("a body that ends by leaving still carries its judged calls")
    func aLeavingBodyKeepsItsJudgedCalls() async throws {
        // Given. The call the build lowered must reach the image whether the
        // body finishes or leaves
        let sut = Procedure(
            body: [
                Statement(binding: .constant("items"), expression: .array([.literal(.int(1)), .literal(.int(2))])
                ),
                Statement(
                    expression: .leave(
                        Leave(
                            reach: .procedure,
                            value: .call(Call(selector: "std.collection.count", arguments: [reference("items")]))
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(2))
    }

    @Test("a loop whose rounds never finish still answers its result")
    func aLoopWhoseRoundsNeverFinishStillAnswers() async throws {
        // Given. A loop's result is read at the exits: a condition that
        // declines at the start runs no round and answers, whatever the rounds
        // would have done. So the result is not "after" the body the way a
        // plain block's is, and a body no run comes back from (here a procedure only
        // the build knows declares never) leaves the loop answerable still. The
        // reader refuses the leaves it can see; this is the type only the build
        // sees, and the run keeps it
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [Statement(expression: refusing(literal("stops")))],
                result: .literal(.string("done"))
            ),
            round: "round"
        )

        let sut = Procedure(
            body: [Statement(binding: .constant("kept"), expression: loop)],
            result: reference("kept")
        )

        // When / Then
        #expect(try await run(sut) == .string("done"))
    }

    @Test("such a loop's name holds what the result reads")
    func aNeverBodiedLoopStillReadsAsItsResult() async throws {
        // Given. The result reads in what the entry left, and the reading says
        // so: `kept` holds the result's string, and a slot that declared int
        // refuses it by that reading rather than by `never`
        let loop = Warp.Expression.loop(
            while: .literal(.bool(false)),
            body: Block(
                body: [Statement(expression: refusing(literal("stops")))],
                result: .literal(.string("done"))
            ),
            round: "round"
        )

        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("kept"), expression: loop),
                        Statement(binding: .constant("said"), expression: .call(Call(
                            selector: "wants",
                            arguments: [.reference([.key("kept")])]
                        ))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(parameters: [Parameter(name: "count", type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("holds string")
        }
    }

    @Test("a result after a statement that never finishes is refused at the build")
    func aResultAfterNeverIsRefused() async throws {
        // Given. The result runs after the body, so it is "after" the same way
        // a trailing statement is; the type reading already knows it (a block
        // ending in never types never), and the refusal must know it too
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(expression: refusing(literal("done")))
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("never finishes before it")
        }
    }

    @Test("a statement after a conditional both of whose arms leave is refused")
    func nothingRunsAfterABranchThatAlwaysLeaves() {
        // Given. Neither arm finishes, so the conditional never does, and the
        // statement after it is unreachable whichever way the condition answers
        let conditional = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ],
            else: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(2)))))
            ]
        )

        // When / Then
        #expect(!validates(body: [
            Statement(expression: conditional),
            Statement(binding: .constant("after"), expression: .literal(.int(3)))
        ]))
    }

    @Test("a name on a conditional both of whose arms leave is refused")
    func aNamedBranchThatAlwaysLeavesIsRefused() {
        // Given. The name could only ever bind what an arm answers, and both
        // arms answer by leaving instead
        let conditional = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ],
            else: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(2)))))
            ]
        )

        // When / Then
        #expect(!validates(body: [Statement(binding: .constant("gone"), expression: conditional)]))
    }

    @Test("an arm that leaves inside a block is still a leaving arm")
    func anArmLeavingInsideAGroupCounts() {
        // Given. The rule reaches through structure because the fact does: a
        // block whose body leaves never finishes, and an arm that ends in one
        // ends every way through the arm
        let conditional = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [
                Statement(
                    expression: .block(
                        Block(body: [
                            Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
                        ])
                    )
                )
            ],
            else: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(2)))))
            ]
        )

        // When / Then
        #expect(!validates(body: [
            Statement(expression: conditional),
            Statement(binding: .constant("after"), expression: .literal(.int(3)))
        ]))
    }

    @Test("a conditional that can decline still lets what follows run")
    func aDecliningBranchIsNotALeave() {
        // Given, with no else, the conditional finishes whenever the condition
        // declines, so the statement after it is reachable
        let conditional = Warp.Expression.conditional(
            .literal(.bool(false)),
            then: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ],
            else: nil
        )

        // When / Then
        #expect(validates(body: [
            Statement(expression: conditional),
            Statement(binding: .constant("after"), expression: .literal(.int(3)))
        ]))
    }

    @Test("a result after a leaving statement is refused at the check")
    func aResultAfterLeavingIsRefused() {
        // Given. The syntactic half of the same rule, held where leaves are
        let sut = Procedure(
            body: [
                Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))
            ],
            result: .literal(.int(2))
        )

        // When / Then
        #expect {
            try Validator().validate(sut)
        } throws: { error in
            "\(error)".contains("never be reached")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  LeaveTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard

// Leaving early: `return`, `break`, `continue`.
//
// They are grammar because checking one needs what a signature has no slot for.
// Whether `return 5` fits depends on what the procedure it is written in
// declared it answers, and whether `break` is allowed depends on there being a
// loop around it. A procedure could be handed the value and could not be told either
// thing. A rescue is for what the world did, so a leave is no failure.
@Suite("A body can stop before its end")
struct LeaveTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("returning answers with what it carries")
    func returningAnswers() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "parameters": [["name": "word", "type": "String"]],
            "returns": "String",
            "body": [
                ["var": "early", "value": "kept going"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "word"], "equal": "stop"],
                        "then": [["value": ["return": "left early"]]]
                    ]
                ]]
            ],
            "result": ["ref": "early"]
        ], importing: ["Standard.Logic.equal"])

        // When
        let stopped = try await answer(sut, ["word": .string("stop")])
        let carried = try await answer(sut, ["word": .string("go")])

        // Then
        #expect(stopped == .string("left early"))
        #expect(carried == .string("kept going"))
    }

    @Test("breaking ends the loop, which answers what it was going to answer")
    func breakingEndsTheLoop() async throws {
        // Given. The loop counts to ten and stops at three. What it answers is
        // its own `result:`, read in the round that stopped: ending early asks
        // nothing new of the type a loop already has.
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "seen", "value": 0],
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": ["of": ["ref": "seen"], "notEqual": 10],
                        "body": [
                            [
                                "set": "seen",
                                "value": ["call": [
                                    "procedure": "Standard.Numeric.plus",
                                    "arguments": [["ref": "seen"], 1]
                                ]
                            ]],
                            [
                                "value": ["conditional": [
                                    "when": ["of": ["ref": "seen"], "equal": 3],
                                    "then": [["value": ["break": Value.null]]]
                                ]
                            ]]
                        ],
                        "result": ["ref": "seen"]
                    ]
                ]]
            ],
            "result": ["ref": "walked"]
        ], importing: ["Standard.Logic.equal", "Standard.Logic.notEqual", "Standard.Numeric.plus"])

        // When / Then
        #expect(try await answer(sut) == .int(3))
    }

    @Test("continuing ends the round and the loop goes on")
    func continuingSkipsARound() async throws {
        // Given. A round cut short wrote nothing further outward, which is what
        // skipping it means. So only the rounds that finished are seen.
        let sut = try loader.loadProcedure([
            "parameters": [["name": "names", "type": "Array<String>"]],
            "body": [
                ["var": "seen", "value": ""],
                [
                    "let": "kept",
                    "value": ["loop": [
                        "while": [
                            "of": ["ref": "kept.index"],
                            "lessThan": ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]
                        ],
                        "body": [
                            ["let": "item", "value": ["ref": "names[kept.index]"]],
                            [
                                "value": ["conditional": [
                                    "when": ["of": ["ref": "item"], "equal": "skip"],
                                    "then": [["value": ["continue": Value.null]]]
                                ]
                            ]],
                            [
                                "set": "seen",
                                "value": [
                                    "format": "${so_far}${item}",
                                    "with": [
                                        "so_far": ["ref": "seen"],
                                        "item": ["ref": "item"]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]]
            ],
            "result": ["ref": "seen"]
        ], importing: [
            "Standard.Collection.count",
            "Standard.Logic.equal",
            "Standard.Comparable.lessThan",
            "Standard.Text.joined",
            "Standard.Text.text"
        ])

        // When
        let answered = try await answer(
            sut,
            ["names": .array([.string("a"), .string("skip"), .string("b")])]
        )

        // Then
        #expect(answered == .string("ab"))
    }

    @Test("a name reaches past the nearest loop to one further out")
    func aNameReachesAnOuterLoop() async throws {
        // Given. The loops already have names, because a statement names what
        // it binds and a loop binds its round state under that name. Reaching
        // past the nearest one is spelling the name that already exists.
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "count", "value": 0],
                [
                    "let": "outer",
                    "value": ["loop": [
                        "while": ["of": ["ref": "count"], "notEqual": 100],
                        "body": [
                            [
                                "let": "inner",
                                "value": ["loop": [
                                    "while": true,
                                    "body": [
                                        [
                                            "set": "count",
                                            "value": ["call": [
                                                "procedure": "Standard.Numeric.plus",
                                                "arguments": [["ref": "count"], 1]
                                            ]
                                        ]],
                                        ["value": ["break": "outer"]]
                                    ]
                                ]
                            ]]
                        ],
                        "result": ["ref": "count"]
                    ]
                ]]
            ],
            "result": ["ref": "outer"]
        ], importing: ["Standard.Logic.notEqual", "Standard.Numeric.plus"])

        // When / Then. One round of each, because the break left both
        #expect(try await answer(sut) == .int(1))
    }

    @Test("a rescue does not catch a body that left on purpose")
    func leavingIsNotFailing() async throws {
        // Given. Leaving is no failure, so a rescue around it has nothing to
        // catch, and the early exit answers what it carries.
        let sut = try loader.loadProcedure([
            "returns": "String",
            "body": [
                [
                    "let": "tried",
                    "value": ["attempt": [
                        "body": [
                            ["let": "checked", "value": ["as": ["of": Value.null, "type": "Int?"]]],
                            ["value": ["return": "left from inside"]]
                        ],
                        "rescue": ["result": "the rescue ran"]
                    ]
                ]]
            ],
            "result": ["ref": "tried"]
        ])

        // When / Then
        #expect(try await answer(sut) == .string("left from inside"))
    }

    @Test("leaving is refused where there is nothing to leave")
    func leavingNeedsSomethingToLeave() {
        // When / Then. A loop's name is not visible to a closure, because a
        // closure is a procedure and runs wherever it is called from
        #expect {
            try loader.loadProcedure([
                "body": [["value": ["break": Value.null]]]
            ])
        } throws: { error in
            "\(error)".contains("no loop here to leave")
        }

        #expect {
            try loader.loadProcedure([
                "body": [
                    [
                        "let": "walked",
                        "value": ["loop": [
                            "while": false,
                            "body": [["value": ["break": "somewhereElse"]]]
                        ]
                    ]]
                ]
            ])
        } throws: { error in
            "\(error)".contains("not a loop around it")
        }
    }

    @Test("a closure cannot leave the loop it was written in")
    func aClosureCannotLeaveAnEnclosingLoop() {
        // When / Then. A closure may be called anywhere, including long after
        // the loop it was written in has ended. So the loops around where it is
        // *written* are not around where it runs.
        #expect {
            try loader.loadProcedure([
                "parameters": [["name": "names", "type": "Array<String>"]],
                "body": [
                    [
                        "let": "walked",
                        "value": ["loop": [
                            "while": false,
                            "body": [
                                [
                                    "let": "kept",
                                    "value": ["call": [
                                        "procedure": "Standard.Collection.filter",
                                        "arguments": [
                                            ["ref": "names"],
                                            [
                                                "closure": [
                                                    "parameters": [["name": "item", "type": "String"]],
                                                    "body": [["value": ["break": Value.null]]]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]]
                            ]
                        ]
                    ]]
                ]
            ])
        } throws: { error in
            "\(error)".contains("no loop here to leave")
        }
    }

    @Test("answering leaves the procedure it was written in, and no other")
    func answeringStaysInItsOwnFrame() async throws {
        // Given. Three ways to reach a body: a run starting at one, a procedure
        // whose implementation is written, and a closure being invoked. When
        // only the first caught an answer, a `return` inside a called body left
        // through its own frame and became the *caller's* answer. Settled
        // against the caller's declaration rather than its own.
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "returns": "String",
                    "body": [
                        ["let": "said", "value": ["call": ["procedure": "helper"]]],
                        [
                            "let": "invoked",
                            "value": ["call": [
                                "procedure": [
                                    "closure": [
                                        "returns": "String",
                                        "body": [["value": ["return": "from the closure"]]]
                                    ]
                                ]
                            ]
                        ]]
                    ],
                    "result": "the outer answer"
                ],
                "helper": [
                    "returns": "String",
                    "body": [["value": ["return": "from the procedure"]]]
                ]
            ]
        ])

        // When / Then
        #expect(try await answer(sut) == .string("the outer answer"))
    }

    @Test("a body naming no result is worth nothing to the checker too")
    func theCheckerAgreesAboutWhatABodyAnswers() async throws {
        // Given. The run answers nothing here, so the checker has to say the
        // same. While it still read the last statement, this passed the block's
        // answer as an int and then handed null over at the run. A program that
        // linked and could never work, which is the one thing linking promises
        // does not happen.
        let sut: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        ["let": "blocked", "value": ["block": ["body": [["let": "inner", "value": 3]]]]],
                        [
                            "let": "used",
                            "value": ["call": [
                                "procedure": "wants",
                                "arguments": [["ref": "blocked"]]
                            ]
                        ]]
                    ],
                    "result": ["ref": "used"]
                ],
                "wants": ["parameters": [["name": "it", "type": "Int"]], "returns": "Int", "result": ["ref": "it"]]
            ]
        ]

        // When / Then
        await #expect {
            try await Builder().build(
                [try loader.loadDocument(sut)] + Module.standard
            )
        } throws: { error in
            "\(error)".contains("holds Null where Int is declared")
        }
    }

    @Test("a body watched by a rescue is still inside the loop around it")
    func anAttemptDoesNotHideTheLoop() async throws {
        // Given. An `attempt` runs in step with the body around it, so a loop
        // around the attempt is a loop around its body. The run always allowed
        // this: a leaving is not a failure, so a rescue lets it past.
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "seen", "value": 0],
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": true,
                        "body": [
                            [
                                "let": "tried",
                                "value": ["attempt": [
                                    "body": [
                                        ["let": "checked", "value": ["as": ["of": Value.null, "type": "Int?"]]],
                                        [
                                            "set": "seen",
                                            "value": ["call": [
                                                "procedure": "Standard.Numeric.plus",
                                                "arguments": [["ref": "seen"], 1]
                                            ]
                                        ]],
                                        ["value": ["break": Value.null]]
                                    ],
                                    "rescue": ["result": "the rescue ran"]
                                ]
                            ]]
                        ],
                        "result": ["ref": "seen"]
                    ]
                ]]
            ],
            "result": ["ref": "walked"]
        ], importing: ["Standard.Numeric.plus"])

        // When / Then
        #expect(try await answer(sut) == .int(1))
    }

    @Test("a loop's result reads what its rounds bound")
    func aLoopResultReadsWhatTheBodyBound() async throws {
        // Given. The checker shows the result what the body declared, so a
        // result naming one has to work. Reading the scope the round started in
        // would show it nothing the round bound.
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "seen", "value": 0],
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": ["of": ["ref": "seen"], "notEqual": 2],
                        "body": [
                            [
                                "set": "seen",
                                "value": ["call": [
                                    "procedure": "Standard.Numeric.plus",
                                    "arguments": [["ref": "seen"], 1]
                                ]
                            ]],
                            ["let": "noted", "value": ["ref": "seen"]]
                        ],
                        "result": ["ref": "noted"]
                    ]
                ]]
            ],
            "result": ["ref": "walked"]
        ], importing: ["Standard.Logic.notEqual", "Standard.Numeric.plus"])

        // When / Then. What the last round bound, not nothing
        #expect(try await answer(sut) == .int(2))
    }

    @Test("a result under a body that always leaves is refused on the result")
    func aResultUnderALeavingBodyIsRefused() {
        // When / Then. The result runs after the body, so it is "after" the
        // same way a trailing statement is
        #expect {
            try loader.loadProcedure([
                "returns": "Int",
                "body": [["value": ["block": [
                    "body": [["value": ["return": 1]]],
                    "result": 2
                ]]]],
                "result": 3
            ])
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("block.result: follows a body that never finishes")
        }
    }

    @Test("nothing may be written after leaving")
    func nothingRunsAfterLeaving() {
        // When / Then. A statement after one that leaves never runs, so the
        // name it was going to bind never binds. Reading it later would read
        // nothing, and there is no kind of program where that is what the
        // author meant.
        #expect {
            try loader.loadProcedure([
                "returns": "String",
                "body": [
                    ["value": ["return": "here"]],
                    ["let": "unreachable", "value": "never"]
                ]
            ])
        } throws: { error in
            "\(error)".contains("would never run")
        }
    }

    @Test("a loop answers what it carries, and leaving does not change its type")
    func leavingDoesNotWidenALoop() throws {
        // Given. `break` carries nothing on purpose. Were it to carry a value,
        // a loop's type would be the join of its result and every break in it,
        // and a loop over strings broken with an int would answer `Any`.
        let sut: Value = [
            "body": [
                [
                    "let": "walked",
                    "value": ["loop": ["while": false, "body": [["value": ["break": 5]]]]
                ]]
            ]
        ]

        // When / Then
        #expect {
            try loader.loadProcedure(sut)
        } throws: { error in
            "\(error)".contains("takes the name of a loop")
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func answer(_ module: Module, _ arguments: [Name: Value] = [:]) async throws -> Value {
        let image = try await Builder().build(
            [module] + Module.standard + [.testing]
        )

        return try await Executor().run(image, arguments: arguments)
    }
}

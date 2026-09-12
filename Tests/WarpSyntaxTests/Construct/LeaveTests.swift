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
// thing.
//
// Before these existed the only way out was to fail on purpose and catch it,
// which meant a successful early exit had to travel down the failure channel.
// These do not: a rescue is for what the world did.
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
            "parameters": ["procedure": "string"],
            "returns": "string",
            "body": [
                ["var": "early", "value": "kept going"],
                [
                    "value": ["conditional": [
                        "when": ["of": ["ref": "procedure"], "equal": "stop"],
                        "then": [["value": ["return": "left early"]]]
                    ]
                ]]
            ],
            "result": ["ref": "early"]
        ], importing: ["std.logic.equal"])

        // When
        let stopped = try await answer(sut, ["procedure": .string("stop")])
        let carried = try await answer(sut, ["procedure": .string("go")])

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
                                    "procedure": "std.math.plus",
                                    "of": ["ref": "seen"],
                                    "arguments": ["value": 1]
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
        ], importing: ["std.logic.equal", "std.logic.notEqual", "std.math.plus"])

        // When / Then
        #expect(try await answer(sut) == .int(3))
    }

    @Test("continuing ends the round and the loop goes on")
    func continuingSkipsARound() async throws {
        // Given. A round cut short wrote nothing further outward, which is what
        // skipping it means. So only the rounds that finished are seen.
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                ["var": "seen", "value": ""],
                [
                    "let": "kept",
                    "value": ["loop": [
                        "while": [
                            "of": ["ref": "kept.index"],
                            "lessThan": ["call": ["procedure": "std.collection.count", "of": ["ref": "names"]]]
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
            "std.collection.count",
            "std.logic.equal",
            "std.math.lessThan",
            "std.text.joined",
            "std.text.text"
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
                                                "procedure": "std.math.plus",
                                                "of": ["ref": "count"],
                                                "arguments": ["value": 1]
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
        ], importing: ["std.logic.notEqual", "std.math.plus"])

        // When / Then. One round of each, because the break left both
        #expect(try await answer(sut) == .int(1))
    }

    @Test("a rescue does not catch a body that left on purpose")
    func leavingIsNotFailing() async throws {
        // Given. This is the whole reason the language needed these. The old
        // way out was to fail deliberately, which a rescue then caught, so a
        // successful early exit had to travel as a failure and could not be
        // told apart from one.
        let sut = try loader.loadProcedure([
            "returns": "string",
            "body": [
                [
                    "let": "tried",
                    "value": ["attempt": [
                        "body": [
                            ["let": "checked", "value": ["as": "number", "of": 0]],
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
        // Given. A loop's name is not visible to a closure, because a closure
        // is a procedure and runs wherever it is called from
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
        // Given. A closure may be called anywhere, including long after the
        // loop it was written in has ended. So the loops around where it is
        // *written* are not around where it runs.
        #expect {
            try loader.loadProcedure([
                "parameters": ["names": "array<string>"],
                "body": [
                    [
                        "let": "walked",
                        "value": ["loop": [
                            "while": false,
                            "body": [
                                [
                                    "let": "kept",
                                    "value": ["call": [
                                        "procedure": "std.collection.filter",
                                        "of": ["ref": "names"],
                                        "arguments": [
                                            "by": [
                                                "closure": [
                                                    "parameters": ["item": "string"],
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
                    "returns": "string",
                    "body": [
                        ["let": "said", "value": ["call": ["procedure": "helper"]]],
                        [
                            "let": "invoked",
                            "value": ["apply": [
                                "procedure": [
                                    "closure": [
                                        "returns": "string",
                                        "body": [["value": ["return": "from the closure"]]]
                                    ]
                                ]
                            ]
                        ]]
                    ],
                    "result": "the outer answer"
                ],
                "helper": [
                    "returns": "string",
                    "body": [["value": ["return": "from the procedure"]]]
                ]
            ]
        ])

        // When / Then
        #expect(try await answer(sut) == .string("the outer answer"))
    }

    @Test("a body naming no result is worth nothing to the checker too")
    func theCheckerAgreesAboutWhatABodyAnswers() throws {
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
                                "arguments": ["it": ["ref": "blocked"]]
                            ]
                        ]]
                    ],
                    "result": ["ref": "used"]
                ],
                "wants": ["parameters": ["it": "int"], "returns": "int", "result": ["ref": "it"]]
            ]
        ]

        // When / Then
        #expect {
            try Builder().build(
                [try loader.loadDocument(sut)] + Module.standard,
                entry: entryName
            )
        } throws: { error in
            "\(error)".contains("holds null where int is declared")
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
                                        ["let": "checked", "value": ["as": "number", "of": 0]],
                                        [
                                            "set": "seen",
                                            "value": ["call": [
                                                "procedure": "std.math.plus",
                                                "of": ["ref": "seen"],
                                                "arguments": ["value": 1]
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
        ], importing: ["std.math.plus"])

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
                                    "procedure": "std.math.plus",
                                    "of": ["ref": "seen"],
                                    "arguments": ["value": 1]
                                ]
                            ]],
                            ["let": "noted", "value": ["ref": "seen"]]
                        ],
                        "result": ["ref": "noted"]
                    ]
                ]]
            ],
            "result": ["ref": "walked"]
        ], importing: ["std.logic.notEqual", "std.math.plus"])

        // When / Then. What the last round bound, not nothing
        #expect(try await answer(sut) == .int(2))
    }

    @Test("a result under a body that always leaves is refused at reading")
    func aResultUnderALeavingBodyIsRefusedAtReading() {
        // Given. The result runs after the body, so it is "after" the same way
        // a trailing statement is; the pair is refused where a document
        // assembles it, validation or no validation to follow
        #expect {
            try loader.statement(from: [
                "value": ["block": [
                    "body": [["value": ["return": 1]]],
                    "result": ["value": 2]
                ]]
            ])
        } throws: { error in
            "\(error)".contains("would never be reached")
        }
    }

    @Test("nothing may be written after leaving")
    func nothingRunsAfterLeaving() {
        // Given. A statement after one that leaves never runs, so the name it
        // was going to bind never binds. Reading it later would read nothing,
        // and there is no shape of program where that is what the author meant.
        #expect {
            try loader.loadProcedure([
                "returns": "string",
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
        // and a loop over strings broken with an int would answer `any`.
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
        let image = try Builder().build(
            [module] + Module.standard + [.testing],
            entry: entryName
        )

        return try await Executor().run(image, arguments: arguments)
    }
}

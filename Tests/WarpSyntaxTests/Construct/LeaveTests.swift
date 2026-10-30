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
// declared it returns, and whether `break` is allowed depends on there being a
// loop around it. A procedure could be handed the value and could not be told either
// thing. A leave is not a failure: a catch is for what the world did.
@Suite("A body can stop before its end")
struct LeaveTests {
    // MARK: - Property
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a return leaves with what it carries")
    func aReturnLeavesWithWhatItCarries() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "parameters": [["name": "word", "type": "String"]],
            "returns": "String",
            "body": [
                ["var": "early", "value": "kept going"],
                [
                    "value": ["conditional": [
                        "when": ["call": ["procedure": "Standard.Logic.equal", "arguments": [["ref": "word"], "stop"]]],
                        "then": [["value": ["return": "left early"]]]
                    ]
                ]],
                ["value": ["return": ["ref": "early"]]]
            ]
        ], importing: ["Standard.Logic.equal"])

        // When
        let stopped = try await returned(sut, ["word": .string("stop")])
        let carried = try await returned(sut, ["word": .string("go")])

        // Then
        #expect(stopped == .string("left early"))
        #expect(carried == .string("kept going"))
    }

    @Test("breaking ends the loop")
    func breakingEndsTheLoop() async throws {
        // Given. The loop counts to ten and stops at three, and what it kept
        // it wrote outward.
        let sut = try loader.loadProcedure([
            "returns": "Int",
            "body": [
                ["var": "seen", "value": 0],
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": ["call": ["procedure": "Standard.Logic.notEqual", "arguments": [["ref": "seen"], 10]]],
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
                                    "when": ["call": ["procedure": "Standard.Logic.equal", "arguments": [["ref": "seen"], 3]]],
                                    "then": [["value": ["break": Value.null]]]
                                ]
                            ]]
                        ]
                    ]
                ]],
                ["value": ["return": ["ref": "seen"]]]
            ]
        ], importing: ["Standard.Logic.equal", "Standard.Logic.notEqual", "Standard.Numeric.plus"])

        // When / Then
        #expect(try await returned(sut) == .int(3))
    }

    @Test("continuing ends the round and the loop goes on")
    func continuingSkipsARound() async throws {
        // Given. A round cut short wrote nothing further outward, which is what
        // skipping it means. So only the rounds that finished are seen.
        let sut = try loader.loadProcedure([
            "returns": "String",
            "parameters": [["name": "names", "type": "Array<String>"]],
            "body": [
                ["var": "seen", "value": ""],
                [
                    "let": "kept",
                    "value": ["loop": [
                        "while": ["call": ["procedure": "Standard.Comparable.lessThan", "arguments": [["ref": "kept.index"], ["call": ["procedure": "Standard.Collection.count", "arguments": [["ref": "names"]]]]]]],
                        "body": [
                            ["let": "item", "value": ["ref": "names[kept.index]"]],
                            [
                                "value": ["conditional": [
                                    "when": ["call": ["procedure": "Standard.Logic.equal", "arguments": [["ref": "item"], "skip"]]],
                                    "then": [["value": ["continue": Value.null]]]
                                ]
                            ]],
                            [
                                "set": "seen",
                                "value": ["call": ["procedure": "Standard.Text.joined", "arguments": [[["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "seen"]]]], ["call": ["procedure": "Standard.Text.text", "arguments": [["ref": "item"]]]]], ""]]]
                            ]
                        ]
                    ]
                ]],
                ["value": ["return": ["ref": "seen"]]]
            ]
        ], importing: [
            "Standard.Collection.count",
            "Standard.Logic.equal",
            "Standard.Comparable.lessThan",
            "Standard.Text.joined",
            "Standard.Text.text"
        ])

        // When
        let returned = try await returned(
            sut,
            ["names": .array([.string("a"), .string("skip"), .string("b")])]
        )

        // Then
        #expect(returned == .string("ab"))
    }

    @Test("a name reaches past the nearest loop to one further out")
    func aNameReachesAnOuterLoop() async throws {
        // Given. The loops already have names, because a statement names what
        // it binds and a loop binds its round state under that name. Reaching
        // past the nearest one is spelling the name that already exists.
        let sut = try loader.loadProcedure([
            "returns": "Int",
            "body": [
                ["var": "count", "value": 0],
                [
                    "let": "outer",
                    "value": ["loop": [
                        "while": ["call": ["procedure": "Standard.Logic.notEqual", "arguments": [["ref": "count"], 100]]],
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
                        ]
                    ]
                ]],
                ["value": ["return": ["ref": "count"]]]
            ]
        ], importing: ["Standard.Logic.notEqual", "Standard.Numeric.plus"])

        // When / Then. One round of each, because the break left both
        #expect(try await returned(sut) == .int(1))
    }

    @Test("a catch does not take a body that left on purpose")
    func leavingIsNotFailing() async throws {
        // Given. Leaving is no failure, so a catch around it has nothing to
        // catch, and the early exit returns what it carries.
        let sut = try loader.loadProcedure([
            "returns": "String",
            "body": [
                ["var": "said", "value": "nothing ran"],
                [
                    "let": "tried",
                    "value": ["try": [
                        "body": [
                            ["let": "checked", "value": ["as": ["of": Value.null, "type": "Int?"]]],
                            ["value": ["return": "left from inside"]]
                        ],
                        "catch": [["set": "said", "value": "the catch ran"]]
                    ]
                ]],
                ["value": ["return": ["ref": "said"]]]
            ]
        ])

        // When / Then
        #expect(try await returned(sut) == .string("left from inside"))
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

    @Test("a return leaves the procedure it was written in, and no other")
    func aReturnStaysInItsOwnFrame() async throws {
        // Given. Three ways to reach a body: a run starting at one, a procedure
        // whose implementation is written, and a closure being invoked. When
        // only the first caught a return value, a `return` inside a called body
        // left through its own frame and became the *caller's* return value,
        // judged against the caller's declaration rather than its own.
        let sut = try loader.loadDocument([
            "procedures": [
                "entry": [
                    "returns": "String",
                    "failing": "anything",
                    "body": [
                        ["let": "said", "value": ["call": ["procedure": "helper"]]],
                        [
                            "let": "invoked",
                            "value": ["call": [
                                "procedure": [
                                    "closure": [
                                        "returns": "String",
                                        "body": [["value": ["conditional": ["when": true, "then": [["value": ["return": "from the closure"]]]]]], ["value": ["return": "not reached"]]]
                                    ]
                                ]
                            ]
                        ]],
                        ["value": ["return": "the outer answer"]]
                    ]
                ],
                "helper": [
                    "returns": "String",
                    "body": [["value": ["conditional": ["when": true, "then": [["value": ["return": "from the procedure"]]]]]], ["value": ["return": "not reached"]]]
                ]
            ]
        ])

        // When / Then
        #expect(try await returned(sut) == .string("the outer answer"))
    }

    @Test("a body watched by a catch is still inside the loop around it")
    func aTryDoesNotHideTheLoop() async throws {
        // Given. A `try` runs in step with the body around it, so a loop
        // around the try is a loop around its body. A leaving is not a
        // failure, so a catch lets it past.
        let sut = try loader.loadProcedure([
            "returns": "Int",
            "body": [
                ["var": "seen", "value": 0],
                [
                    "let": "walked",
                    "value": ["loop": [
                        "while": true,
                        "body": [
                            [
                                "let": "tried",
                                "value": ["try": [
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
                                    "catch": [["let": "noted", "value": "the catch ran"]]
                                ]
                            ]]
                        ]
                    ]
                ]],
                ["value": ["return": ["ref": "seen"]]]
            ]
        ], importing: ["Standard.Numeric.plus"])

        // When / Then
        #expect(try await returned(sut) == .int(1))
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

    @Test("a break carries nothing")
    func aBreakCarriesNothing() throws {
        // Given. A loop has no value, so a `break` has nothing to carry.
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
    private func returned(_ module: Module, _ arguments: [Name: Value] = [:]) async throws -> Value {
        let image = try await Builder().build(
            [module] + Module.standard + [.testing]
        )

        return try await Executor().run(image, arguments: arguments)
    }
}

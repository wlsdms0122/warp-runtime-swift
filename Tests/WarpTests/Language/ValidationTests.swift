//
//  ValidationTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A document is checked against itself, before anything is resolved. The walk
// is structural, which is what these ask: not whether a particular notation
// rejects a particular text, but what the language considers visible where.
@Suite
struct ValidationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a name the module bound is not introduced again at any depth")
    func aBoundNameIsNotIntroducedAgainAtAnyDepth() {
        // Given — linking folds a constant wherever its name is read, so a name
        // introduced under that spelling would never be the one that answers.
        // The rule is the whole body's: a sub scope is where a reader is least
        // able to see that the name was already taken.
        func module(introducing statement: Statement) throws -> Module {
            try Module(
                name: "app",
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        body: [
                            Statement(
                                id: "got",
                                expression: .block(Block(
                                    body: [statement],
                                    result: reference("limit")
                                ))
                            )
                        ],
                        result: reference("got")
                    )
                ]
            )
        }

        // When / Then
        #expect(throws: ValidationError.self) {
            try Validator().validate(
                module(introducing: Statement(id: "limit", expression: .literal(.int(9))))
            )
        }
    }

    @Test("but writing one is refused for what it is, not for introducing a name")
    func writingABoundNameIsRefusedAsAWrite() throws {
        // Given — an assignment names a name rather than introducing one, and
        // the two mistakes have different fixes: one is to pick another
        // spelling, the other is to declare a variable.
        // When / Then
        let error = #expect(throws: ValidationError.self) {
            try Module(
                name: "app",
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        body: [
                            Statement(id: "limit", binding: .assignment, expression: .literal(.int(9)))
                        ]
                    )
                ]
            )
        }

        #expect(error?.message.contains("declare it as a variable to write it") == true)
    }

    @Test("nor by the name a construct hands its body")
    func aBoundNameIsNotWhatAConstructHandsItsBody() {
        // Given — the same rule where the name is the language's to introduce
        // rather than a statement's: a walk's element, a loop's round, and the
        // failure an attempt rescues.
        func module(running expression: Warp.Expression) throws -> Module {
            try Module(
                name: "app",
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        body: [Statement(id: "got", expression: expression)],
                        result: reference("limit")
                    )
                ]
            )
        }

        let body = Block(body: [Statement(expression: .literal(.null))])

        // When / Then
        #expect(throws: ValidationError.self) {
            try Validator().validate(module(running: .iteration(over: .array([]), body: body.body, element: "limit")))
        }
        #expect(throws: ValidationError.self) {
            try Validator().validate(module(running: .loop(while: .literal(.bool(false)), body: body, round: "limit")))
        }
        #expect(throws: ValidationError.self) {
            try Validator().validate(module(running: .attempt(body, rescue: body, failure: "limit")))
        }
    }

    @Test("nor inside a closure a constant holds")
    func aBoundNameIsNotIntroducedInsideAConstantsClosure() {
        // Given — a constant's own expression is a body like any other. Read
        // without this rule, a closure among the constants may introduce a name
        // one of its siblings has, and what that name means then depends on
        // which of the two the reader is standing in.
        func module(_ procedure: Procedure) throws -> Module {
            try Module(
                name: "app",
                constants: [
                    "apply": .closure(procedure),
                    "limit": .literal(.int(3))
                ],
                procedures: [entryName: Procedure(body: [])]
            )
        }

        // When / Then — the two ways a closure introduces a name of its own
        #expect(throws: ValidationError.self) {
            try Validator().validate(module(Procedure(
                signature: Signature(parameters: ["limit": Parameter(type: .int)], returns: .int),
                body: [],
                result: reference("limit")
            )))
        }
        #expect(throws: ValidationError.self) {
            try Validator().validate(module(Procedure(
                signature: Signature(returns: .int),
                body: [Statement(id: "limit", expression: .literal(.int(9)))],
                result: reference("limit")
            )))
        }
    }

    @Test("a constant sees the constants declared beside it and nothing else")
    func aConstantReadsOnlyItsSiblings() throws {
        // Given — a chain and not a circle. `aaa` reads `bbb`, declared right
        // beside it, so nothing about `aaa` is wrong: `bbb` is the one reading
        // a name nothing here settles, and the refusal stands on it.
        let error = #expect(throws: ValidationError.self) {
            try Module(
                name: "pricing",
                constants: ["aaa": reference("bbb"), "bbb": reference("nowhere")],
                procedures: [entryName: Procedure(body: [])],
                identity: Identity([0x01])
            )
        }

        // Then
        #expect(error?.place?.rendered == "pricing@01/const.bbb")
        #expect(error?.message.contains("aaa") == false)

        // And the name it reads is said, since that is the half of the mistake
        // the place cannot point at
        #expect(error?.message.contains("nowhere") == true)
    }

    @Test("a construct in a call's operand is refused at the check")
    func aConstructInACallOperandIsRefused() {
        // Given — a document cannot even write one there, and the run would
        // refuse it; a program assembled directly meets the same rule before
        // anything runs. The body a word is to run travels as a closure.
        let arm = [Statement(id: "kept", expression: .literal(.int(1)))]
        let sut = [
            Statement(
                id: "said",
                expression: .dispatch(
                    Dispatch(selector: "shout", arguments: [
                        "text": .conditional(.literal(.bool(true)), then: arm, else: nil)
                    ])
                )
            )
        ]

        // When / Then — bare, and buried inside a value shape alike
        #expect(!validates(body: sut))
        #expect(
            !validates(body: [
                Statement(
                    id: "said",
                    expression: .invoke(
                        .closure(Procedure(body: [])),
                        arguments: [
                            "value": .array([
                                .conditional(.literal(.bool(true)), then: arm, else: nil)
                            ])
                        ]
                    )
                )
            ])
        )
    }

    @Test("a construct in a condition is refused at the check")
    func aConstructInAConditionIsRefused() {
        // Given — the run asks a condition purely, the same fact an operand
        // has, so the same rule refuses a construct there
        let construct = Warp.Expression.block(Block(body: [], result: .literal(.bool(true))))

        // When / Then — a branch's condition, and a loop's
        #expect(
            !validates(body: [
                Statement(expression: .conditional(construct, then: [], else: nil))
            ])
        )
        #expect(
            !validates(body: [
                Statement(
                    expression: .loop(
                        while: construct,
                        body: Block(body: [], result: nil),
                        round: "round"
                    )
                )
            ])
        )
    }

    @Test("a branch where a value is wanted is refused at the check")
    func aBranchWhereAValueIsWantedIsRefused() {
        // Given — a branch answers nothing, so a slot that exists to hold an
        // answer has nothing to take from one; refused for that reason
        // rather than as a null that fails to fit downstream
        let branch = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [Statement(id: "kept", expression: .literal(.int(1)))],
            else: nil
        )

        // When / Then — a result slot, an array element, a record field
        #expect(
            !validates(
                body: [Statement(id: "grouped", expression: .block(Block(body: [], result: branch)))]
            )
        )
        #expect(!validates(body: [Statement(id: "list", expression: .array([branch]))]))
        #expect(!validates(body: [Statement(id: "pair", expression: .record(["a": branch]))]))
    }

    @Test("a walk where a value is wanted is refused at the check")
    func aWalkWhereAValueIsWantedIsRefused() {
        // Given — a walk answers nothing, the same fact a branch has, so the
        // same slots refuse it
        let walk = Warp.Expression.iteration(
            over: .array([.literal(.int(1))]),
            body: [],
            element: "walk"
        )

        // When / Then
        #expect(!validates(body: [Statement(id: "list", expression: .array([walk]))]))
        #expect(!validates(body: [Statement(id: "pair", expression: .record(["a": walk]))]))
    }

    @Test("a name is visible only after the statement that introduced it")
    func namesAreVisibleAfterTheirStatement() {
        // Given
        let forward = [
            Statement(id: "first", expression: reference("second")),
            Statement(id: "second", expression: .literal(.int(1)))
        ]
        let backward = [
            Statement(id: "first", expression: .literal(.int(1))),
            Statement(id: "second", expression: reference("first"))
        ]

        // When / Then
        #expect(!validates(body: forward))
        #expect(validates(body: backward))
    }

    @Test("two statements at one level may not share a name")
    func siblingNamesMustDiffer() {
        // Given
        let sut = [
            Statement(id: "same", expression: .literal(.int(1))),
            Statement(id: "same", expression: .literal(.int(2)))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }


    @Test("a parameter is a name the body may read and may not introduce again")
    func parametersAreVisibleAndDeclared() throws {
        // Given — the signature and the body are one scope, so a name is
        // introduced once
        let readsIt = Procedure(
            signature: Signature(parameters: ["name": Parameter(type: .string)]),
            body: [Statement(id: "greeting", expression: reference("name"))]
        )
        let redeclaresIt = Procedure(
            signature: Signature(parameters: ["name": Parameter(type: .string)]),
            body: [Statement(id: "name", expression: .literal(.string("other")))]
        )

        // When / Then
        try Validator().validate(readsIt)

        #expect(throws: (any Error).self) {
            try Validator().validate(redeclaresIt)
        }
    }

    @Test("a reference must start with a name")
    func referenceMustHaveAHead() {
        // Given
        let sut = Warp.Expression.reference([.index(0)])

        // When / Then
        #expect(!validates(sut))
    }

    @Test("an index reference is checked like any other name")
    func indexReferenceHeadIsChecked() {
        // Given — `items[${cursor}]` reads `cursor`, so a typo in it is the
        // same mistake as a typo anywhere else
        let sut = Warp.Expression.reference(
            [.key("items"), .indexRef([.key("cursor")])]
        )

        // When / Then
        #expect(!validates(sut, visible: ["items"]))
        #expect(validates(sut, visible: ["items", "cursor"]))
    }

    @Test("a template's placeholders resolve against its bindings, not the scope")
    func templatePlaceholdersAreClosed() {
        // Given — only the binding expressions reach outward
        let sut = interpolated(spelling(reference("name")))

        // When / Then
        #expect(validates(sut, visible: ["name"]))
        #expect(!validates(sut, visible: ["who"]))
    }

    @Test("a name nothing declared is visible nowhere")
    func undeclaredNamesAreNotVisible() throws {
        // Given — there is one way a name gets here, and it is being declared.
        // A run's own values arrive as arguments like everything else.
        let read = Procedure(body: [Statement(id: "read", expression: reference("run", "id"))])
        let taken = Procedure(
            signature: Signature(parameters: ["run": Parameter(type: .object(.any))]),
            body: [Statement(id: "read", expression: reference("run", "id"))]
        )

        // When / Then
        #expect(throws: ValidationError.self) {
            try Validator().validate(read)
        }

        try Validator().validate(taken)
    }

    @Test("a module is held to the words it says it imports", arguments: [
        [] as Set<String>,
        ["count", "plus"]
    ])
    func aModuleIsHeldToItsImports(_ claimed: Set<String>) {
        // Given — a caller decides what to grant from this list and then links
        // what it granted, so a list that says less than the program sends
        // links a word nobody allowed, and one that says more takes a grant the
        // program never uses
        #expect(throws: ValidationError.self) {
            try Module(
                imports: claimed,
                procedures: [
                    entryName: Procedure(
                        body: [
                            Statement(
                                id: "counted",
                                expression: .dispatch(Dispatch(
                                    receiver: .literal(.array([.int(1)])),
                                    selector: "count"
                                ))
                            )
                        ]
                    )
                ]
            )
        }
    }

    @Test("a module that claims nothing states what it sends")
    func anUnclaimedModuleStatesWhatItSends() throws {
        // Given — a caller assembling shapes in Swift holds the module and has
        // nobody to disclose it to, so there is no claim to be held to. What
        // travels is written from this, and what is written has to be true.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "counted",
                            expression: .dispatch(Dispatch(
                                receiver: .literal(.array([.int(1)])),
                                selector: "count"
                            ))
                        )
                    ]
                )
            ]
        )

        // Then
        #expect(sut.imports == ["count"])
    }

    @Test("a word the module declares itself is not one it imports")
    func ownWordsAreNotImports() throws {
        // Given — what a module brings with it is not what it asks for
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "greet"))
                        )
                    ]
                ),
                "greet": Procedure(body: [], result: .literal(.string("hello")))
            ]
        )

        // Then
        #expect(sut.imports.isEmpty)
    }

    @Test("a result expression is checked against what the body left visible")
    func resultsSeeTheWholeBody() throws {
        // Given
        let sut = Procedure(
            body: [Statement(id: "made", expression: .literal(.int(1)))],
            result: .record(["ok": reference("made"), "bad": reference("never")])
        )

        // When / Then
        #expect(throws: ValidationError.self) {
            try Validator().validate(sut)
        }
    }
}

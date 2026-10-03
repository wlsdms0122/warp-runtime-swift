//
//  ValidationTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// A document is checked against itself, before anything is resolved. The walk
// is structural, which is what these ask: not whether a particular notation
// rejects a particular text, but what the language considers visible where.
@Suite("A document checked against itself")
struct ValidationTests {
    // A procedure the host answers, written where a closure literal stands.
    private struct OneQuery: Query {
        typealias Parameters = NoParameters

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            .int(1)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a module is held to the procedures it says it imports", arguments: [
        (claimed: [] as Set<Name>, refusal: "uses [\"std.collection.count\"], which it does not import"),
        (claimed: ["std.collection.count", "std.math.plus"] as Set<Name>, refusal: "imports [\"std.math.plus\"], which it does not use")
    ])
    func aModuleIsHeldToItsImports(_ claimed: Set<Name>, refusal: String) {
        // Given. A host decides what to grant from this list and then links
        // what it granted, so a list that says less than the program sends
        // links a procedure nobody allowed, and one that says more takes a grant the
        // program never uses

        // When / Then
        #expect {
            try Module(
                imports: claimed,
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("counted"), expression: .call(Call(
                                selector: "std.collection.count",
                                arguments: [.literal(.array([.int(1)]))]
                            )))
                        ]
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains(refusal)
        }
    }

    @Test("a name the module bound is not introduced again at any depth")
    func aBoundNameIsNotIntroducedAgainAtAnyDepth() {
        // Given. Compiling folds a constant wherever its name is read, so a name
        // introduced under that spelling would never be the one that answers.
        // The rule is the whole body's: a sub scope is where a reader is least
        // able to see that the name was already taken.
        func module(introducing statement: Statement) throws -> Module {
            try Module(
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("got"), expression: .block(Block(
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
        #expect {
            try Validator().validate(
                module(introducing: Statement(binding: .constant("limit"), expression: .literal(.int(9))))
            )
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'limit' collides with a name the module bound, which it would take the place of")
        }
    }

    @Test("but writing one is refused for what it is, not for introducing a name")
    func writingABoundNameIsRefusedAsAWrite() throws {
        // Given. An assignment names a name rather than introducing one, and
        // the two mistakes have different fixes: one is to pick another
        // spelling, the other is to declare a variable.

        // When / Then
        let error = #expect(throws: ValidationError.self) {
            try Module(
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .assignment([.key("limit")]), expression: .literal(.int(9)))
                        ]
                    )
                ]
            )
        }

        #expect(error?.message.contains("Declare it as a variable to write it") == true)
    }

    @Test("nor by the name a construct hands its body")
    func aBoundNameIsNotWhatAConstructHandsItsBody() {
        // Given. The same rule where the name is what a loop's round and the
        // failure an attempt rescues are bound under.
        func module(running expression: Warp.Expression) throws -> Module {
            try Module(
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [Statement(binding: .constant("limit"), expression: expression)],
                        result: reference("limit")
                    )
                ]
            )
        }

        let body = Block(body: [Statement(expression: .literal(.null))])

        // When / Then
        #expect {
            try Validator().validate(module(running: .loop(while: .literal(.bool(false)), body: body)))
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'limit' collides with a name the module bound, which it would take the place of")
        }
        #expect {
            try Validator().validate(module(running: .attempt(body, rescue: body)))
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'limit' collides with a name the module bound, which it would take the place of")
        }
    }

    @Test("nor inside a closure a constant holds")
    func aBoundNameIsNotIntroducedInsideAConstantsClosure() {
        // Given. A constant's own expression is a body like any other. Read
        // without this rule, a closure among the constants may introduce a name
        // one of its siblings has, and what that name means then depends on
        // which of the two the reader is standing in.
        func module(_ procedure: Procedure) throws -> Module {
            try Module(
                constants: [
                    "apply": .closure(procedure),
                    "limit": .literal(.int(3))
                ],
                procedures: [entryName: Procedure(access: .public, body: [])]
            )
        }

        // When / Then. The two ways a closure introduces a name of its own
        #expect {
            try Validator().validate(module(Procedure(
                signature: Signature(parameters: [Parameter(name: "limit", type: .int)], returns: .int),
                body: [],
                result: reference("limit")
            )))
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'limit' collides with a name the module bound, which it would take the place of")
        }
        #expect {
            try Validator().validate(module(Procedure(
                signature: Signature(returns: .int),
                body: [Statement(binding: .constant("limit"), expression: .literal(.int(9)))],
                result: reference("limit")
            )))
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'limit' collides with a name the module bound, which it would take the place of")
        }
    }

    @Test("nor a variable's spelling inside a closure a constant holds")
    func aVariablesNameIsNotIntroducedInsideAConstantsClosure() {
        // Given. A constant cannot read `count`, and its closure still may not
        // introduce the spelling
        let closure = Procedure(
            signature: Signature(returns: .int),
            body: [Statement(binding: .constant("count"), expression: .literal(.int(1)))],
            result: reference("count")
        )

        // When / Then
        #expect {
            try Module(
                constants: ["apply": .closure(closure)],
                variables: ["count": .literal(.int(0))],
                procedures: [entryName: Procedure(access: .public, body: [])]
            )
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'count' collides with a name the module bound, which it would take the place of")
        }
    }

    @Test("a constant sees the constants declared beside it and nothing else")
    func aConstantReadsOnlyItsSiblings() throws {
        // Given / When. A chain and not a cycle. `aaa` reads `bbb`, declared
        // right beside it, so nothing about `aaa` is wrong: `bbb` is the one
        // reading a name nothing here settles, and the refusal stands on it.
        let error = #expect(throws: ValidationError.self) {
            try Module(
                constants: ["aaa": reference("bbb"), "bbb": reference("nowhere")],
                procedures: [entryName: Procedure(access: .public, body: [])],
                identity: Identity([0x01])
            )
        }

        // Then
        #expect(error?.place?.rendered == "01/constants.bbb")
        #expect(error?.message.contains("aaa") == false)

        // And the name it reads is said, since that is the half of the mistake
        // the place cannot point at
        #expect(error?.message.contains("nowhere") == true)
    }

    @Test("a construct in a call's operand is refused at the check")
    func aConstructInACallOperandIsRefused() {
        // Given. A document cannot even write one there, and the run would
        // refuse it; a program assembled directly meets the same rule before
        // anything runs. The body a procedure is to run travels as a closure.
        let arm: Body = [Statement(binding: .constant("kept"), expression: .literal(.int(1)))]
        let sut: Body = [
            Statement(binding: .constant("said"), expression: .call(
                Call(selector: "app.shout", arguments: [.conditional(.literal(.bool(true)), then: arm, else: nil)])
            ))
        ]

        // When / Then. Bare, and held inside a value type alike
        #expect(!validates(body: sut))
        #expect(
            !validates(body: [
                Statement(binding: .constant("said"), expression: .apply(
                        .closure(Procedure(body: [])),
                        arguments: [
                            .array([
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
        // Given. The run reads a condition rather than runs it, the same fact an operand has,
        // so the same rule refuses a construct there
        let construct = Warp.Expression.block(Block(body: [], result: .literal(.bool(true))))

        // When / Then. A conditional's condition, and a loop's
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
                        body: Block(body: [], result: nil)
                    )
                )
            ])
        )
    }

    @Test("a conditional where a value is wanted is refused at the check")
    func aBranchWhereAValueIsWantedIsRefused() {
        // Given. A conditional answers nothing, so a slot that exists to hold an
        // answer has nothing to take from one; refused for that reason rather
        // than as a null that fails to fit downstream
        let conditional = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [Statement(binding: .constant("kept"), expression: .literal(.int(1)))],
            else: nil
        )

        // When / Then. A result slot, an array element, a record field
        #expect(
            !validates(
                body: [Statement(binding: .constant("blocked"), expression: .block(Block(body: [], result: conditional)))]
            )
        )
        #expect(!validates(body: [Statement(binding: .constant("list"), expression: .array([conditional]))]))
        #expect(!validates(body: [Statement(binding: .constant("pair"), expression: .record(["a": conditional]))]))
    }

    @Test("a name is visible only after the statement that introduced it")
    func namesAreVisibleAfterTheirStatement() {
        // Given
        let forward: Body = [
            Statement(binding: .constant("first"), expression: reference("second")),
            Statement(binding: .constant("second"), expression: .literal(.int(1)))
        ]
        let backward: Body = [
            Statement(binding: .constant("first"), expression: .literal(.int(1))),
            Statement(binding: .constant("second"), expression: reference("first"))
        ]

        // When / Then
        #expect(!validates(body: forward))
        #expect(validates(body: backward))
    }

    @Test("two statements at one level may not share a name")
    func siblingNamesMustDiffer() {
        // Given
        let sut: Body = [
            Statement(binding: .constant("same"), expression: .literal(.int(1))),
            Statement(binding: .constant("same"), expression: .literal(.int(2)))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a parameter is a name the body may read and may not introduce again")
    func parametersAreVisibleAndDeclared() throws {
        // Given. A parameter's spelling is taken for the whole body
        let readsIt = Procedure(
            signature: Signature(parameters: [Parameter(name: "name", type: .string)]),
            body: [Statement(binding: .constant("greeting"), expression: reference("name"))]
        )
        let redeclaresIt = Procedure(
            signature: Signature(parameters: [Parameter(name: "name", type: .string)]),
            body: [Statement(binding: .constant("name"), expression: .literal(.string("other")))]
        )

        // When / Then
        try Validator().validate(readsIt)

        #expect {
            try Validator().validate(redeclaresIt)
        } throws: { error in
            error is ValidationError && "\(error)".contains("'name' is a parameter of the procedure")
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
        // Given. `items[cursor]` reads `cursor`, so a typo in it is the same
        // mistake as a typo anywhere else
        let sut = Warp.Expression.reference(
            [.key("items"), .indexRef([.key("cursor")])]
        )

        // When / Then
        #expect(!validates(sut, visible: ["items"]))
        #expect(validates(sut, visible: ["items", "cursor"]))
    }

    @Test("a reference inside a call's operand is checked like any other")
    func aReferenceInsideAnOperandIsChecked() {
        // Given
        let sut = interpolated(spelling(reference("name")))

        // When / Then
        #expect(validates(sut, visible: ["name"]))
        #expect(!validates(sut, visible: ["who"]))
    }

    @Test("a name nothing declared is visible nowhere")
    func undeclaredNamesAreNotVisible() throws {
        // Given. There is one way a name gets here, and it is being declared. A
        // run's own values arrive as arguments like everything else.
        let read = Procedure(body: [Statement(binding: .constant("read"), expression: reference("run", "id"))])
        let taken = Procedure(
            signature: Signature(parameters: [Parameter(name: "run", type: .dictionary(.any))]),
            body: [Statement(binding: .constant("read"), expression: reference("run", "id"))]
        )

        // When / Then
        #expect {
            try Validator().validate(read)
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("reference { ref: run.id } names 'run', which is not visible here")
        }

        try Validator().validate(taken)
    }

    @Test("a list wrong in both directions says which procedures moved, not which lists")
    func bothDifferencesAreSaidApart() {
        // Given / When. A module sending thirty procedures would leave an
        // author diffing two lists by eye, and the two differences are two
        // mistakes with two fixes: one procedure is a grant nobody disclosed,
        // the other is a grant nothing uses.
        let error = #expect(throws: ValidationError.self) {
            try Module(
                imports: ["std.math.minus"],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("counted"), expression: .call(Call(
                                selector: "std.collection.count",
                                arguments: [.literal(.array([.int(1)]))]
                            )))
                        ]
                    )
                ]
            )
        }

        // Then
        #expect(
            error?.message
                == "uses [\"std.collection.count\"], which it does not import,"
                    + " and imports [\"std.math.minus\"], which it does not use"
        )
    }

    @Test("a module that claims nothing states what it sends")
    func anUnclaimedModuleStatesWhatItSends() throws {
        // Given / When. A caller assembling types in Swift holds the module and
        // has nobody to disclose it to, so there is no claim to be held to.
        // What travels is written from this, and what is written has to be
        // true.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("counted"), expression: .call(Call(
                            selector: "std.collection.count",
                            arguments: [.literal(.array([.int(1)]))]
                        )))
                    ]
                )
            ]
        )

        // Then
        #expect(sut.imports == ["std.collection.count"])
    }

    @Test("a module calling its own by the name the build knows it by imports nothing")
    func aSiblingCallIsNotAnImport() async throws {
        // Given / When. A module calls a sibling by its declared spelling, and
        // a spelling this document declares is not an import. The honest empty
        // list is accepted.
        let sut = try Module(
            imports: [],
            procedures: [
                "wallet.pay": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("charged"), expression: .call(Call(selector: "wallet.fee")))
                    ]
                ),
                "wallet.fee": Procedure(body: [], result: .literal(.int(1)))
            ]
        )

        // Then
        #expect(sut.imports.isEmpty)

        // And the build agrees the two spellings are one declaration
        await #expect(throws: Never.self) {
            try await Builder().build([sut])
        }
    }

    @Test("a claim about a type the language names is refused where the document is read")
    func aClaimAboutABuiltinTypeIsRefused() throws {
        // When / Then. A claim is about a declared type: a value of `int`
        // wears no name a run could read, so no declaration could answer for
        // it.
        #expect {
            try Module(
                imports: [],
                contracts: ["app.Described": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("app.Described"))], returns: .string)]],
                claims: ["int": ["app.Described"]],
                procedures: [
                    "int.describe": Procedure(
                        signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .string),
                        body: [],
                        result: .literal(.string("int"))
                    ),
                    entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))
                ]
            )
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("'int' is a type the language names, and a claim is about a declared type")
        }
    }

    @Test("a procedure is not data, so it cannot stand as a literal")
    func aProcedureLiteralIsRefused() throws {
        // Given. The one value type a program cannot carry. A closure is made
        // by running the expression that writes one, so a literal holding one
        // is a program no text spells and nothing reads back. Only a caller
        // assembling types in Swift can build it, and this is where that
        // stops.
        let carried = Value.procedure(
            Closure.assembled()
        )

        // When / Then
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [Statement(binding: .constant("held"), expression: .literal(carried))]
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("a procedure is not data")
        }

        // And a body a program carries is written the way one is written
        #expect(throws: Never.self) {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("held"), expression: .closure(Procedure(body: [])))
                        ]
                    )
                ]
            )
        }
    }

    @Test("a result expression is checked against what the body left visible")
    func resultsSeeTheWholeBody() throws {
        // Given
        let sut = Procedure(
            body: [Statement(binding: .constant("made"), expression: .literal(.int(1)))],
            result: .record(["ok": reference("made"), "bad": reference("never")])
        )

        // When / Then
        #expect {
            try Validator().validate(sut)
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("reference { ref: never } names 'never', which is not visible here")
        }
    }

    @Test("a private procedure the host answers is refused in a module that is no document")
    func aPrivateNativeNeedsADocument() throws {
        // Given. A private procedure answered by the host, which a link joins
        // to its code by the document that declares it.
        let procedures: [Name: Procedure] = [
            "app.ticket": Procedure(
                access: .private,
                signature: Signature(returns: .int),
                implementation: .query(TicketQuery())
            )
        ]

        // When / Then. Refused where the module is made, so a compile and a
        // build of it agree. Under a document it stands.
        #expect {
            try Module(procedures: procedures)
        } throws: { error in
            "\(error)".contains("answered by the host in a module that is no document")
        }
        #expect(throws: Never.self) {
            try Module(procedures: procedures, identity: Identity([0x01]))
        }
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
        // Given. With no else, the conditional finishes whenever the condition
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

    @Test("a closure body is validated where it is written")
    func closureBodyIsValidatedAtItsSite() {
        // Given. The body may read what surrounds the literal and what the
        // literal declares, and nothing else
        let readsEnclosing = Warp.Expression.closure(
            Procedure(body: [], result: reference("outer"))
        )
        let readsItsOwn = Warp.Expression.closure(
            Procedure(
                signature: Signature(parameters: [Parameter(name: "mine", type: .int)]),
                body: [],
                result: reference("mine")
            )
        )
        let readsNothingReal = Warp.Expression.closure(
            Procedure(body: [], result: reference("nowhere"))
        )

        // When / Then
        #expect(validates(readsEnclosing, visible: ["outer"]))
        #expect(!validates(readsEnclosing))
        #expect(validates(readsItsOwn))
        #expect(!validates(readsNothingReal))
    }

    @Test("a closure literal is a body, and one written as the host's code is refused at the literal")
    func aClosureLiteralOfTheHostsCodeIsRefused() {
        // Given / When
        let refusal = #expect(throws: ValidationError.self) {
            try Module(procedures: [entryName: Procedure(
                access: .public,
                body: [
                    Statement(
                        binding: .constant("f"),
                        expression: .closure(Procedure(implementation: .query(OneQuery())))
                    )
                ],
                result: .apply(.reference([.key("f")]), arguments: [])
            )])
        }

        // Then. At the literal, where the author wrote it
        #expect(
            refusal.map(String.init(describing:))
                == "procedures.entry.body.f[0].closure: a closure is a body, and this one is the host's code"
        )
    }

    @Test("a name on a conditional is refused")
    func aNameOnABranchIsRefused() {
        // Given. A conditional answers nothing, so its name could never bind
        let sut = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [Statement(expression: .literal(.int(1)))],
            else: nil
        )

        // When / Then. Under any of the three spellings
        #expect(!validates(body: [Statement(binding: .constant("probe"), expression: sut)]))
        #expect(!validates(body: [Statement(binding: .variable("probe"), expression: sut)]))
        #expect(
            !validates(body: [
                Statement(binding: .variable("probe"), expression: .literal(.int(0))),
                Statement(binding: .assignment([.key("probe")]), expression: sut)
            ])
        )
    }

    @Test("a closure parameter may not take a constant's name")
    func aClosureParameterDoesNotShadowAConstant() throws {
        // Given. Compiling folds a constant wherever its name is read, so a
        // closure parameter under that name would never be the one that
        // answers; refused where the top-level signature's is
        let procedure = Procedure(
            signature: Signature(),
            body: [
                Statement(binding: .constant("f"), expression: .closure(Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "greeting", type: .string)]
                        ),
                        body: [],
                        result: .reference([.key("greeting")])
                    ))
                )
            ],
            result: .literal(.int(1))
        )

        // When / Then. There is no such module to hand anywhere: making one is
        // what refuses
        #expect {
            try Module(
                constants: ["greeting": .literal(.string("hi"))],
                procedures: [entryName: procedure]
            )
        } throws: { error in
            "\(error)".contains("take the place of")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

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
// rejects a particular text, but what the language considers visible where,
// which grammar each name holds, and where each word of a type stands.
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

    // Sending two procedures, the second standing at a place nothing before it does.
    private struct ScatteredQuery: Query {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case first = 0
            case apart = 5

            // MARK: - Property
            var selector: Name {
                switch self {
                case .first:
                    return "Int.plus"

                case .apart:
                    return "Int.minus"
                }
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.first)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a module is held to the procedures it says it imports", arguments: [
        (claimed: [] as Set<Name>, refusal: "uses [\"Standard.Collection.count\"], which it does not import"),
        (claimed: ["Standard.Collection.count", "Standard.Numeric.plus"] as Set<Name>, refusal: "imports [\"Standard.Numeric.plus\"], which it does not use")
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
                                selector: "Standard.Collection.count",
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

    @Test("a body inside another may introduce a name the module bound")
    func aNestedBodyMayIntroduceABoundName() throws {
        // Given. Inside the arm `limit` is the arm's own
        let sut = try Module(
            constants: ["limit": .literal(.int(3))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            expression: .conditional(
                                .literal(.bool(true)),
                                then: [Statement(binding: .constant("limit"), expression: .literal(.int(9)))],
                                else: nil
                            )
                        )
                    ],
                    result: reference("limit")
                )
            ]
        )

        // When / Then
        try Validator().validate(sut)
    }

    @Test("but writing one is refused as a write")
    func writingABoundNameIsRefusedAsAWrite() throws {
        // Given. An assignment names a name rather than introducing one, and a
        // constant is no variable

        // When / Then
        let error = #expect(throws: ValidationError.self) {
            try Module(
                constants: ["limit": .literal(.int(3))],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .assignment([.name("limit")]), expression: .literal(.int(9)))
                        ]
                    )
                ]
            )
        }

        #expect(error?.message.contains("Declare it as a variable to write it") == true)
    }

    @Test("and so may the name a construct hands its body")
    func aConstructMayHandItsBodyABoundName() throws {
        // Given. The name a loop's round and the failure an attempt rescues
        // are bound under
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
        try Validator().validate(module(running: .loop(while: .literal(.bool(false)), body: body.body)))
        try Validator().validate(module(running: .attempt(body, rescue: body)))
    }

    @Test("and so may a closure a constant holds, a sibling's spelling or a variable's")
    func aConstantsClosureMayIntroduceABoundName() throws {
        // Given. A constant's own expression is a body like any other
        func module(_ procedure: Procedure) throws -> Module {
            try Module(
                constants: [
                    "apply": .closure(procedure),
                    "limit": .literal(.int(3))
                ],
                variables: ["count": .literal(.int(0))],
                procedures: [entryName: Procedure(access: .public, body: [])]
            )
        }

        // When / Then. The two ways a closure introduces a name of its own
        try Validator().validate(module(Procedure(
            signature: Signature(parameters: [Parameter(name: "limit", type: .int)], returns: .int),
            body: [],
            result: reference("limit")
        )))
        try Validator().validate(module(Procedure(
            signature: Signature(returns: .int),
            body: [Statement(binding: .constant("count"), expression: .literal(.int(9)))],
            result: reference("count")
        )))
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

    @Test("a construct is written only as a statement's value, and refused wherever a value is wanted")
    func aConstructWhereAValueIsWantedIsRefused() throws {
        // Given. No document writes one there; a module made in Swift meets
        // the same rule where it is made. Each place below wants a value
        let construct = Warp.Expression.conditional(.literal(.bool(true)), then: [], else: nil)
        let places: [(Body, String)] = [
            ([Statement(expression: .call(Call(selector: "App.f", arguments: [construct])))], "body[0].call.arguments[0]"),
            ([Statement(expression: .apply(.closure(Procedure(body: [])), arguments: [.array([construct])]))], "body[0].call.arguments[0][0]"),
            ([Statement(expression: .conditional(construct, then: [], else: nil))], "body[0].conditional.condition"),
            ([Statement(expression: .loop(while: construct, body: []))], "body[0].loop.condition"),
            ([Statement(binding: .constant("list"), expression: .array([construct]))], "body.list[0].array[0]"),
            ([Statement(binding: .constant("pair"), expression: .struct(["a": construct]))], "body.pair[0].struct.fields.a"),
            ([Statement(binding: .constant("read"), expression: .cast(construct, as: .int, optional: false))], "body.read[0].cast.subject"),
            ([Statement(expression: .leave(Leave(reach: .procedure, value: construct)))], "body[0].leave")
        ]

        for (body, place) in places {
            // When
            let error = #expect(throws: ValidationError.self) {
                try Module(procedures: [entryName: Procedure(body: body)])
            }

            // Then
            #expect(error?.message == Expression.constructWhereAValueIsWanted)
            #expect(error?.place?.rendered == "procedures.entry.\(place)")
        }

        // And a constant's and a variable's start, which a module holds
        #expect(throws: ValidationError.self) { try Module(constants: ["c": construct]) }
        #expect(throws: ValidationError.self) { try Module(variables: ["v": construct]) }
    }

    @Test("a value call in an operand, a constant and a variable's start is the build's to judge")
    func aValueCallInAnOperandLoads() throws {
        // Given. Whether a value call answers without running is said by the
        // type written for the value, which the load does not read
        let called = Warp.Expression.apply(reference("f"), arguments: [])
        let read = Statement(binding: .constant("f"), expression: .closure(Procedure(body: [], result: .literal(.int(1)))))

        // When / Then. A call's operand, a condition, and a value call held
        // inside a list an operand holds
        #expect(validates(body: [read, Statement(expression: .call(Call(selector: "App.g", arguments: [called])))]))
        #expect(validates(body: [read, Statement(expression: .conditional(called, then: [], else: nil))]))
        #expect(validates(body: [read, Statement(expression: .call(Call(selector: "App.g", arguments: [.array([called])])))]))
        _ = try Module(constants: ["f": .closure(Procedure(body: [])), "c": .apply(reference("f"), arguments: [])])
        _ = try Module(
            constants: ["f": .closure(Procedure(body: []))],
            variables: ["v": .apply(reference("f"), arguments: [])]
        )
    }

    @Test("a construct that binds the name says what it holds, and the author does not")
    func aConstructBoundNameTakesNoDeclaration() throws {
        // Given. A loop binds the round under the statement's name
        let statement = Statement(
            binding: .constant("walk", declared: .int),
            expression: .loop(while: .literal(.bool(false)), body: [])
        )

        // When / Then. Refused where the module is made
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(access: .public, body: [statement], result: .literal(.int(1)))
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("this construct binds the name")
        }
    }

    @Test("a procedure whose sends stand apart is refused where the module is made")
    func aProcedureSendingFromScatteredPlacesIsRefused() {
        // Given / When / Then. A run reaches a sent procedure by the place the procedure
        // names it at, so a place nothing stands at reaches nothing.
        #expect {
            try Module(
                procedures: [
                    "App.scattered": Procedure(
                        signature: Signature(returns: .int),
                        implementation: .query(ScatteredQuery())
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("this procedure sends procedures standing at [0, 5]")
        }
    }

    @Test("a document writes only the variables it declares")
    func aDocumentWritesOnlyItsOwnVariables() {
        // Given. One write of `total`
        let write = Statement(binding: .assignment([.name("total")]), expression: .literal(.int(1)))

        // When / Then. Taken at the load of the document declaring
        // `total`, and refused at the load of one that does not
        #expect(throws: Never.self) {
            try Module(
                variables: ["total": .literal(.int(0))],
                procedures: ["App.poke": Procedure(body: [write])]
            )
        }
        #expect {
            try Module(procedures: ["Other.poke": Procedure(body: [write])])
        } throws: { error in
            error is ValidationError && "\(error)".contains("assigns 'total', which is not visible here")
        }
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
        // Given. A parameter is a name the body introduced before its first
        // statement
        let readsIt = Procedure(
            signature: Signature(parameters: [Parameter(name: "name", type: .string)]),
            body: [Statement(binding: .constant("greeting"), expression: reference("name"))]
        )
        let redeclaresIt = Procedure(
            signature: Signature(parameters: [Parameter(name: "name", type: .string)]),
            body: [Statement(binding: .constant("name"), expression: .literal(.string("other")))]
        )

        // When / Then
        _ = try Module(procedures: [entryName: readsIt])

        #expect {
            try Module(procedures: [entryName: redeclaresIt])
        } throws: { error in
            error is ValidationError && "\(error)".contains("'name' is a parameter this body takes")
        }
    }

    @Test("a parameter declared twice is refused where the module is made, however it was made")
    func aParameterDeclaredTwiceIsRefused() throws {
        // Given. Two parameters under one name would be one name the body
        // reads two ways
        let twice = Procedure(
            signature: Signature(parameters: [Parameter(name: "x", type: .int), Parameter(name: "x", type: .string)]),
            body: [],
            result: .literal(.int(1))
        )

        // When / Then
        #expect {
            try Module(procedures: [entryName: twice])
        } throws: { error in
            error is ValidationError && "\(error)".contains("parameters[1]: declares 'x' twice")
        }
    }

    @Test("a name no path reads back is refused where it is declared, read or not")
    func aNameNoPathReadsIsRefused() throws {
        // Given. A path reads `a.b` as the field `b` of `a`, so a statement,
        // a parameter or a module's constant spelled that way is never reached
        let statement = Procedure(body: [Statement(binding: .constant("a.b"), expression: .literal(.int(1)))])
        let parameter = Procedure(
            signature: Signature(parameters: [Parameter(name: "a[0]", type: .int)]),
            body: []
        )

        // When / Then
        for procedure in [statement, parameter] {
            #expect {
                try Module(procedures: [entryName: procedure])
            } throws: { error in
                error is ValidationError && "\(error)".contains("is no name a path reads")
            }
        }

        #expect {
            try Module(
                constants: ["App.k": .literal(.int(1))],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("constants.App.k: 'App.k' is no name a path reads")
        }
    }

    @Test("a mark on the head is refused where the module is made")
    func aMarkedHeadIsRefused() throws {
        // Given / When / Then. The head is a name a scope holds, so there is
        // nothing before it that could have been absent. A front end that
        // builds segments directly is told so where the module is made
        #expect {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(
                            parameters: [
                                Parameter(name: "items", type: .array(.string))
                            ]
                        ),
                        body: [],
                        result: .reference([.name("items", optional: true), .index(0)])
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("marks the head optional")
        }
    }

    @Test("a path's brackets hold a whole number, a text or a path, however the module was made", arguments: [
        Value.double(1.5), .null, .bool(true), .array([.int(1)]), .bytes([1]), .dictionary(Value.Dictionary([:]))
    ])
    func aBracketHoldsWhatAPathIsWrittenWith(index: Value) throws {
        // Given. A path written as text holds no other value between its
        // brackets, so a front end that builds segments directly is held to
        // the same three
        let read = Procedure(
            access: .public,
            signature: Signature(parameters: [Parameter(name: "d", type: .dictionary(key: .named("Hashable"), value: .int))]),
            body: [],
            result: .reference([.name("d"), .index(index)])
        )

        // When / Then
        #expect {
            try Module(procedures: [entryName: read])
        } throws: { error in
            error is ValidationError && "\(error)".contains("what stands between a path's brackets is a whole number")
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
            [.name("items"), .indexRef([.name("cursor")])]
        )

        // When / Then
        #expect(!validates(sut, visible: ["items"]))
        #expect(validates(sut, visible: ["items", "cursor"]))

        // And in a write's path, where the index is read the same way, a
        // mark on its head included
        let items = Statement(binding: .variable("items"), expression: .array([.literal(.int(1))]))
        let write: (Path) -> Body = { path in
            [items, Statement(binding: .assignment(path), expression: .literal(.int(2)))]
        }

        #expect(!validates(body: write([.name("items"), .indexRef([.name("cursor")])])))
        #expect(!validates(body: write([.name("items"), .indexRef([.name("cursor", optional: true)])]), visible: ["cursor"]))
        #expect(validates(body: write([.name("items"), .indexRef([.name("cursor")])]), visible: ["cursor"]))
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
        let read = Procedure(body: [Statement(binding: .constant("read"), expression: .reference([.name("run"), .index("id")]))])
        let taken = Procedure(
            signature: Signature(parameters: [Parameter(name: "run", type: .dictionary(key: .string, value: .any))]),
            body: [Statement(binding: .constant("read"), expression: .reference([.name("run"), .index("id")]))]
        )

        // When / Then
        #expect {
            try Module(procedures: [entryName: read])
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("reads 'run', which is not visible here")
        }

        _ = try Module(procedures: [entryName: taken])
    }

    @Test("a list wrong in both directions says which procedures moved, not which lists")
    func bothDifferencesAreSaidApart() {
        // Given / When. A module sending thirty procedures would leave an
        // author diffing two lists by eye, and the two differences are two
        // mistakes with two fixes: one procedure is a grant nobody disclosed,
        // the other is a grant nothing uses.
        let error = #expect(throws: ValidationError.self) {
            try Module(
                imports: ["Standard.Numeric.minus"],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [
                            Statement(binding: .constant("counted"), expression: .call(Call(
                                selector: "Standard.Collection.count",
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
                == "uses [\"Standard.Collection.count\"], which it does not import,"
                    + " and imports [\"Standard.Numeric.minus\"], which it does not use"
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
                            selector: "Standard.Collection.count",
                            arguments: [.literal(.array([.int(1)]))]
                        )))
                    ]
                )
            ]
        )

        // Then
        #expect(sut.imports == ["Standard.Collection.count"])
    }

    @Test("a module calling its own by the name the build knows it by imports nothing")
    func aSiblingCallIsNotAnImport() async throws {
        // Given / When. A module calls a sibling by its declared spelling, and
        // a spelling this document declares is not an import. The honest empty
        // list is accepted.
        let sut = try Module(
            imports: [],
            procedures: [
                "Wallet.pay": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("charged"), expression: .call(Call(selector: "Wallet.fee")))
                    ]
                ),
                "Wallet.fee": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        // Then
        #expect(sut.imports.isEmpty)

        // And the build agrees the two spellings are one declaration
        await #expect(throws: Never.self) {
            try await Builder().build([sut])
        }
    }

    @Test("a claim keyed by a word the language writes itself is refused where the module is made")
    func aClaimKeyedByALanguageWordIsRefused() throws {
        // When / Then. `Any` is a word the language writes itself, so a claim
        // keyed by it names no type a document writes.
        #expect {
            try Module(
                imports: [],
                contracts: ["App.Described": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
                claims: ["Any": ["App.Described"]],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
            )
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("extensions.Any: 'Any' is no name a module gives a type or a contract")
        }
    }

    @Test("a module giving a type an empty set of contracts or members is refused where it is made", arguments: [
        ("extensions.Int.satisfies", ["Int": []], [:]),
        ("extensions.Int.procedures", [:], ["Int": []])
    ] as [(String, [Head: Set<Name>], [Head: Set<Name>])])
    func anEmptyGivingIsRefused(place: String, claims: [Head: Set<Name>], members: [Head: Set<Name>]) throws {
        // When / Then. A type given nothing is written as no extension, so a
        // module saying it gives one an empty set would write a document that
        // reads back as another.
        #expect {
            try Module(
                imports: [],
                claims: claims,
                members: members,
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains(place)
        }
    }

    @Test("a claim about a type the language names stands as one about a declared type")
    func aClaimAboutALanguageTypeStands() throws {
        // When / Then. `Int` is a type a value is an instance of, as a declared
        // struct is, and `Int` names no document to import.
        let sut = try Module(
            imports: [],
            contracts: ["App.Described": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: ["Int": ["App.Described"]],
            members: ["Int": ["describe"]],
            procedures: [
                "Int.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .string),
                    body: [],
                    result: .literal(.string("Int"))
                ),
                entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))
            ]
        )

        #expect(sut.claims == ["Int": ["App.Described"]])
    }

    @Test("a name in the types namespace is held to one grammar where a module built in Swift spells it", arguments: [
        ("procedures.App.keep.parameters[0]", [:], TypeExpression.named("a b"), [:]),
        ("types.Int", ["Int": .alias(.string)], .int, [:]),
        ("procedures.App.keep.parameters[0]", [:], .parameter(name: "T"), ["T": ["Array<Int>"]]),
        ("procedures.App.keep.parameters[0]", [:], .parameter(name: "Self"), [:]),
        ("procedures.App.keep.parameters[0]", [:], .parameter(name: "A.B"), [:]),
        ("procedures.App.keep.parameters[0]", [:], .parameter(name: "Int"), [:]),
        ("procedures.App.keep.parameters[0]", [:], .parameter(name: "some"), ["some": ["App.Shown"]])
    ] as [(String, [Name: TypeDeclaration], TypeExpression, [Name: Set<Name>])])
    func aTypeNamespaceNameHoldsOneGrammar(
        place: String,
        types: [Name: TypeDeclaration],
        parameter: TypeExpression,
        bounds: [Name: Set<Name>]
    ) throws {
        // When / Then
        #expect {
            try Module(
                types: types,
                procedures: [
                    "App.keep": Procedure(
                        signature: Signature(parameters: [Parameter(name: "value", type: parameter)], bounds: bounds),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("\(place): ")
                && ("\(error)".contains("is no name a module gives a type or a contract") || "\(error)".contains("is no type parameter's name"))
        }
    }

    @Test("a struct type's field and a contract's parameter are value names, held where a module built in Swift writes them")
    func aFieldAndAContractParameterAreValueNames() throws {
        // When / Then. A dot in a field's name is a step to a path, so no path
        // reaches the field
        #expect {
            try Module(
                types: ["App.Held": .struct(["a.b": .int])],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("types.App.Held.fields")
                && "\(error)".contains("is no name a path reads")
        }

        // And a contract's parameter is a parameter like any other
        #expect {
            try Module(
                contracts: [
                    "App.Shown": ["show": Signature(parameters: [Parameter(name: "o.f", type: .selfType)], returns: .string)]
                ],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("contracts.App.Shown.procedures.show.parameters[0]")
                && "\(error)".contains("is no name a path reads")
        }
    }

    @Test("a literal may hold a map, which a document writes as the map literal that makes it")
    func aLiteralMapStands() throws {
        // When / Then
        #expect(throws: Never.self) {
            try Module(
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [],
                        result: .literal(.array([.dictionary(["a": .int(1)])]))
                    )
                ]
            )
        }
    }

    @Test("what stands between the brackets is data, however the path was made")
    func anIndexIsData() async throws {
        // Given
        let items = Statement(binding: .variable("items"), expression: .array([.literal(.int(1))]))
        let carried = try await procedureValue()

        // When / Then. A read and a write. Which value is a position is the
        // build's to judge, by what is indexed
        #expect(!validates(body: [items, Statement(binding: .constant("x"), expression: .reference([.name("items"), .index(carried)]))]))
        #expect(!validates(body: [items, Statement(binding: .assignment([.name("items"), .index(carried)]), expression: .literal(.int(2)))]))
        #expect(validates(body: [items, Statement(binding: .constant("x"), expression: .reference([.name("items"), .index(-1)]))]))
    }

    @Test("every name a path reads is a value's name, however the path was made", arguments: [
        Name("a.b"), Name(" a"), Name("a?"), Name("a[0]")
    ])
    func aPathReadsValueNames(step: Name) throws {
        // Given
        let literal = Statement(binding: .variable("d"), expression: .struct(["a": .literal(.int(1))]))

        // When / Then. A read and a write
        #expect(!validates(body: [literal, Statement(binding: .constant("x"), expression: .reference([.name("d"), .name(step)]))]))
        #expect(!validates(body: [literal, Statement(binding: .assignment([.name("d"), .name(step)]), expression: .literal(.int(2)))]))
        #expect(validates(body: [literal, Statement(binding: .constant("x"), expression: .reference([.name("d"), .name("a")]))]))
    }

    @Test("a literal holds no struct, at whatever depth it holds one", arguments: [
        Value.struct(Struct(name: "Ghost.T", ["x": .int(1)])),
        .array([.struct(Struct(name: "Int", ["x": .int(1)]))])
    ])
    func aNamedLiteralIsRefused(carried: Value) throws {
        // When / Then
        #expect {
            try Module(
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(carried))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("a literal holds a struct")
        }
    }

    @Test("a literal holds no fraction without a finite value, at whatever depth it holds one", arguments: [
        Value.double(.nan),
        .array([.double(1.5), .double(.infinity)]),
        .dictionary(["a": .array([.double(-.infinity)])])
    ])
    func aNonFiniteLiteralIsRefused(carried: Value) throws {
        // When / Then
        #expect {
            try Module(
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(carried))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("a literal holds a fraction with no finite value")
        }
    }

    @Test("a closure writes no bounds, since the procedure around it owns them")
    func aClosureWritesNoBounds() throws {
        // Given
        let closure = Procedure(
            signature: Signature(parameters: [Parameter(name: "y", type: .parameter(name: "T"))], bounds: ["T": ["Standard.Comparable"]]),
            body: [],
            result: .literal(.int(1))
        )

        // When / Then
        #expect {
            try Module(procedures: [entryName: Procedure(body: [], result: .closure(closure))])
        } throws: { error in
            error is ValidationError && "\(error)".contains("a closure writes no bounds")
        }
    }

    @Test("a bound on a name no slot writes refuses, however the signature was made")
    func aBoundOnAnUnwrittenNameRefuses() throws {
        // Given. A signature made in Swift, bounding `T` where every slot
        // writes `Int`
        let procedure = Procedure(
            signature: Signature(parameters: [Parameter(name: "of", type: .int)], bounds: ["T": ["Standard.Comparable"]]),
            body: [],
            result: .literal(.int(1))
        )

        // When / Then
        #expect {
            try Module(procedures: [entryName: procedure])
        } throws: { error in
            error is ValidationError && "\(error)".contains("bounds name T, and no slot writes `some T`")
        }
    }

    @Test("a contract's procedure made in Swift writes no bounds")
    func aContractProcedureWritesNoBounds() throws {
        // When / Then. No document can write one; a module made in Swift is
        // held to the same rule at the load
        #expect {
            try Module(
                contracts: [
                    "App.Kept": [
                        "keep": Signature(
                            parameters: [Parameter(name: "of", type: .selfType), Parameter(name: "with", type: .parameter(name: "T"))],
                            bounds: ["T": ["App.Kept"]]
                        )
                    ]
                ],
                procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.int(1)))]
            )
        } throws: { error in
            error is ValidationError && "\(error)".hasPrefix("contracts.App.Kept.procedures.keep.parameters[1]: ")
                && "\(error)".contains("a contract's procedure writes no bounds")
        }
    }

    @Test("a procedure is not data, so it cannot stand as a literal")
    func aProcedureLiteralIsRefused() async throws {
        // Given. The one value type a program cannot carry. A closure is made
        // by running the expression that writes one, so a literal holding one
        // is a program no text spells and nothing reads back. Only a caller
        // assembling types in Swift can build it, and this is where that
        // stops.
        let carried = try await procedureValue()

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
            result: map(["ok": reference("made"), "bad": reference("never")])
        )

        // When / Then
        #expect {
            try Module(procedures: [entryName: sut])
        } throws: { error in
            error is ValidationError
                && "\(error)".contains("reads 'never', which is not visible here")
        }
    }

    @Test("a private procedure the host answers is refused in a module that is no document")
    func aPrivateNativeNeedsADocument() throws {
        // Given. A private procedure answered by the host, which a link joins
        // to its code by the document that declares it.
        let procedures: [Name: Procedure] = [
            "App.ticket": Procedure(
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

    @Test("an arm that leaves inside a nested conditional is still a leaving arm")
    func anArmLeavingInsideAGroupCounts() {
        // Given. The rule reaches through structure because the fact does: a
        // conditional whose arms both leave never finishes, and an arm that
        // ends in one ends every way through the arm
        let conditional = Warp.Expression.conditional(
            .literal(.bool(true)),
            then: [
                Statement(
                    expression: .conditional(
                        .literal(.bool(false)),
                        then: [Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(1)))))],
                        else: [Statement(expression: .leave(Leave(reach: .procedure, value: .literal(.int(3)))))]
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

    @Test("a result after a leaving statement is refused at the load")
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
            try Module(procedures: [entryName: sut])
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
                result: .apply(.reference([.name("f")]), arguments: [])
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
                Statement(binding: .assignment([.name("probe")]), expression: sut)
            ])
        )
    }

    @Test("a closure parameter may take a constant's spelling")
    func aClosureParameterMayShadowAConstant() throws {
        // Given. Inside the closure `greeting` is its parameter
        let procedure = Procedure(
            signature: Signature(),
            body: [
                Statement(binding: .constant("f"), expression: .closure(Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "greeting", type: .string)]
                        ),
                        body: [],
                        result: .reference([.name("greeting")])
                    ))
                )
            ],
            result: .literal(.int(1))
        )

        // When / Then
        _ = try Module(
            constants: ["greeting": .literal(.string("hi"))],
            procedures: [entryName: procedure]
        )
    }

    @Test("a name that is no struct and comes back to itself refuses at the load")
    func aNameComingBackRefusesAtTheLoad() throws {
        // Given. A struct may name itself, and a name that is no struct
        // spells no type where it reaches itself, through names or a structure
        let cycles: [[Name: TypeDeclaration]] = [
            ["Loop": .alias(.named("Loop"))],
            ["A": .alias(.named("B")), "B": .alias(.named("A"))],
            ["List": .alias(.array(.named("List")))]
        ]

        for types in cycles {
            // When / Then
            #expect {
                try Module(
                    types: types,
                    procedures: [
                        entryName: Procedure(
                            access: .public,
                            signature: Signature(),
                            body: [],
                            result: .literal(.int(1))
                        )
                    ]
                )
            } throws: { error in
                error is ValidationError && "\(error)".contains("names itself through what it stands for")
            }
        }

        // A recursive type loads: the name reaches a type on the way back.
        #expect(throws: Never.self) {
            try Module(
                types: ["Tree": .struct(["children": .array(.named("Tree"))])],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(),
                        body: [],
                        result: .literal(.int(1))
                    )
                ]
            )
        }
    }

    @Test("a name is a constant or a variable, and not both")
    func aNameIsBoundOnce() {
        // When / Then
        #expect {
            try Module(
                imports: [],
                constants: ["limit": .literal(.int(1))],
                variables: ["limit": .literal(.int(2))],
                procedures: [entryName: Procedure(access: .public, body: [], result: reference("limit"))]
            )
        } throws: { error in
            "\(error)".contains("one name holds one thing")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

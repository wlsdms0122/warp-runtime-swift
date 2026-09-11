//
//  ConstraintTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// A constraint is a declared membership, and a bounded `some T` takes only what
// the membership admits. These are the places the bound turns a reading into a
// refusal before anything runs, and the one place it waits for the run, because
// the text said nothing.
@Suite("What a bounded type parameter admits")
struct ConstraintTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a reading outside the constraint refuses at the build")
    func aReadingOutsideTheConstraintRefusesAtTheLink() throws {
        // Given. Both sides of `lessThan` are booleans, and `Comparable` admits
        // none of them. The reading is a literal, so the build can see it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .bool),
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.bool(true)),
                        selector: "std.math.lessThan",
                        arguments: ["value": .literal(.bool(false))]
                    ))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("arithmetic on two strings refuses at the build")
    func arithmeticOnTwoStringsRefusesAtTheLink() throws {
        // Given. The two sides agree, so the one type parameter reads one
        // thing. Agreement is not admission: `Numeric` does not admit text.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.string("a")),
                        selector: "std.math.plus",
                        arguments: ["value": .literal(.string("b"))]
                    ))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Numeric' does not admit")
        }
    }

    @Test("a value arriving through any is judged at the boundary")
    func aValueArrivingThroughAnyIsJudgedAtTheBoundary() async throws {
        // Given. The parameter is declared `any`, so the build reads nothing and
        // the membership is judged where the value arrives
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["left": Parameter(type: .any)],
                        returns: .bool
                    ),
                    body: [],
                    result: .call(Call(
                        receiver: reference("left"),
                        selector: "std.math.lessThan",
                        arguments: ["value": .literal(.int(1))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, arguments: ["left": .bool(true)])
        } throws: { error in
            "\(error)".contains("nothing 'std.Comparable' admits takes bool")
        }
    }

    @Test("a module declares a constraint of its own and the bound holds")
    func aModuleDeclaresAConstraintOfItsOwn() async throws {
        // Given. The membership lives in the declaration, so a signature writes
        // the name and the same judgment std's words get is this one's
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .parameter(name: "T", constraint: "Scalar"))],
                        returns: .parameter(name: "T", constraint: "Scalar")
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(
                        selector: "keep",
                        arguments: ["value": .literal(.int(7))]
                    ))
                )
            ]
        )

        // When
        let answered = try await run(sut)

        // Then
        #expect(answered == .int(7))
    }

    @Test("a reading a declared constraint does not admit refuses at the build")
    func aDeclaredConstraintRefusesAtItsOwnBound() throws {
        // Given
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .parameter(name: "T", constraint: "Scalar"))],
                        returns: .parameter(name: "T", constraint: "Scalar")
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "keep",
                        arguments: ["value": .literal(.double(1.5))]
                    ))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Scalar' does not admit")
        }
    }

    @Test("a signature naming a constraint nobody declares refuses at the build")
    func anUndeclaredConstraintRefusesAtTheLink() throws {
        // Given. Unreached code still has to compile, and a bound naming
        // nothing is a defect whether or not a call ever fills it
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .parameter(name: "T", constraint: "Sortable"))],
                        returns: .parameter(name: "T", constraint: "Sortable")
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("names 'Sortable', which no module in this link declares")
        }
    }

    @Test("one parameter written with two constraints refuses at the build")
    func twoBoundsOnOneParameterRefuseAtTheLink() throws {
        // Given. The bound is written inline, so two slots writing different
        // bounds for one name are two claims about one thing
        let sut = try Module(
            constraints: ["A": [.int], "B": [.string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "left": Parameter(type: .parameter(name: "T", constraint: "A")),
                            "right": Parameter(type: .parameter(name: "T", constraint: "B"))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("One parameter takes one constraint")
        }
    }

    @Test("a bare mention and a bounded mention are one bounded parameter")
    func aBareMentionRidesTheBoundedOne() throws {
        // Given. A bounded `some T` in one slot and a bare one in another are
        // one parameter bounded once, so the bound judges both readings
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "left": Parameter(type: .parameter(name: "T", constraint: "Scalar")),
                            "right": Parameter(type: .parameter(name: "T"))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "keep",
                        arguments: [
                            "left": .literal(.double(1.0)),
                            "right": .literal(.double(2.0))
                        ]
                    ))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Scalar' does not admit")
        }
    }

    @Test("a name cannot be a type and a constraint at once")
    func aNameDeclaredAsTypeAndConstraintRefuses() throws {
        // Given
        let sut = try Module(
            types: ["Scalar": .int],
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("both a type and a constraint")
        }
    }

    @Test("a constraint admitting nothing refuses at the build")
    func anEmptyConstraintRefusesAtTheLink() throws {
        // Given. No parameter it bounds could ever be filled, which is the same
        // fact an empty oneOf states
        let sut = try Module(
            constraints: ["Nothing": []],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    @Test("a type parameter hidden in a declared type refuses at the build")
    func aParameterInADeclaredTypeRefusesAtTheLink() throws {
        // Given. A declared type has no call to fill a parameter, and a bound
        // hidden behind the name would otherwise escape every judgment
        let sut = try Module(
            types: ["Weird": .parameter(name: "T", constraint: "Sortable")],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .named("Weird"))]
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a parameter behind a procedure type in a declared type refuses too")
    func aParameterInADeclaredProcedureTypeRefusesAtTheLink() throws {
        // Given. A declared type is not a filling site however deep the
        // parameter hides: nothing ever binds it, so the claim would go
        // unjudged everywhere
        let sut = try Module(
            types: [
                "Callback": .procedure(
                    Signature(
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraint: "Scalar"))]
                    )
                )
            ],
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a name that reaches only names refuses at the build")
    func aNameOnlyCycleRefusesAtTheLink() throws {
        // Given. A shape may name itself through a shape, and a name that only
        // names names never becomes one
        let cycles: [[Name: TypeExpression]] = [
            ["Loop": .named("Loop")],
            ["A": .named("B"), "B": .named("A")]
        ]

        for types in cycles {
            let sut = try Module(
                types: types,
                procedures: [
                    entryName: Procedure(
                        signature: Signature(),
                        body: [],
                        result: .literal(.int(1))
                    )
                ]
            )

            // When / Then
            #expect {
                try builder.build([sut] + Module.standard, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("through nothing but names")
            }
        }

        // A recursive shape passes: the name reaches a shape on the way back.
        let tree = try Module(
            types: ["Tree": .record(["children": .array(.named("Tree"))])],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        #expect(throws: Never.self) {
            try builder.build([tree] + Module.standard, entry: entryName)
        }
    }

    @Test("a constraint member is a concrete shape")
    func aConstraintMemberMustBeConcrete() throws {
        // Given. `some` in member position stands for a type and names none;
        // admitting it would also let a membership chase itself forever
        for member in [TypeExpression.parameter(name: "S", constraint: "Loop"), .any, .never] {
            let sut = try Module(
                constraints: ["Loop": [member]],
                procedures: [
                    entryName: Procedure(
                        signature: Signature(),
                        body: [],
                        result: .literal(.int(1))
                    )
                ]
            )

            // When / Then
            #expect {
                try builder.build([sut] + Module.standard, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("a member is a concrete shape")
            }
        }
    }

    @Test("a oneOf no member of the bound can spell refuses at the build")
    func aOneOfOutsideTheBoundRefusesAtTheLink() throws {
        // Given. Words on a Numeric slot: no member of the constraint can spell
        // them, so no call could ever fit this parameter
        let sut = try Module(
            procedures: [
                "pick": Procedure(
                    signature: Signature(
                        parameters: [
                            "speed": Parameter(
                                type: .parameter(name: "N", constraint: "std.Numeric"),
                                oneOf: ["fast", "slow"]
                            )
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("oneOf admits nothing")
        }
    }

    @Test("a fraction candidate is judged by the fraction's one spelling")
    func aFractionCandidateIsJudgedByItsSpelling() throws {
        // Given. A fraction spells with its point, so `1` on a double slot is
        // the int's spelling and a member no fraction could ever match, and
        // `1e0`/`1.00` are second spellings of a fraction that has one
        func module(oneOf candidates: [String]) throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        signature: Signature(
                            parameters: [
                                "level": Parameter(type: .double, oneOf: candidates)
                            ]
                        ),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        }

        for dead in ["1", "1e0", "1.50", "1e-5"] {
            #expect("\(dead)") {
                try builder.build([module(oneOf: ["2.0", dead])] + Module.standard, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("'\(dead)'")
            }
        }

        // The spellings a document itself writes are alive. The exponent form
        // included, sign and padding and all.
        #expect(throws: Never.self) {
            try builder.build([module(oneOf: ["1.0", "1.5", "1e-05"])] + Module.standard, entry: entryName)
        }
    }

    @Test("oneOf membership is the number's worth, not its bit pattern")
    func aOneOfMeetsANumberByWorth() async throws {
        // Given. The two zeros are one worth in the language's own order, so a
        // list that writes one admits the other
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: [
                            "level": Parameter(type: .double, oneOf: ["0.0", "1.5"])
                        ]
                    ),
                    body: [],
                    result: reference("level")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .double(-0.0)]) == .double(-0.0))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["level": .double(2.5)])
        }
    }

    @Test("a slot that names no one kind reads a candidate as either")
    func aBoundedSlotMeetsEitherKindByWorth() async throws {
        // Given. A constraint-bounded parameter admits wholes and fractions
        // alike, so `"1"` is a live member and worth carries across kinds: the
        // same rule `number` takes, pinned so the build's candidate judge and
        // this boundary cannot drift apart
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: [
                            "level": Parameter(
                                type: .parameter(name: "N", constraint: "std.Numeric"),
                                oneOf: ["1", "2.5"]
                            )
                        ]
                    ),
                    body: [],
                    result: reference("level")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["level": .int(1)]) == .int(1))
        #expect(try await run(sut, arguments: ["level": .double(1.0)]) == .double(1.0))
        #expect(try await run(sut, arguments: ["level": .double(2.5)]) == .double(2.5))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["level": .int(3)])
        }
    }

    @Test("a member hiding a refused shape behind a name still refuses")
    func aMemberBehindANameIsJudgedResolved() throws {
        // Given. An alias is a name for a shape, so what the shape may not be
        // the alias may not be either
        let sut = try Module(
            types: ["Anything": .any],
            constraints: ["Loose": [.named("Anything")]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("a member is a concrete shape")
        }
    }

    @Test("a recursive shape compared with itself agrees instead of recursing")
    func aRecursiveShapeAcceptsItself() throws {
        // Given. A shape that names itself walks back into the comparison it is
        // inside; meeting the pair again is agreement, not a regress
        let types = TypeTable(types: ["Node": .record(["next": .named("Node")])])

        // When / Then
        #expect(TypeExpression.named("Node").accepts(.named("Node"), in: types))

        let sut = try Module(
            types: ["Node": .record(["value": .int, "next": .any])],
            procedures: [
                "read": Procedure(
                    signature: Signature(
                        parameters: ["node": Parameter(type: .named("Node"))],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("node"), .key("value")])
                ),
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["node": Parameter(type: .named("Node"))],
                        returns: .int
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "read",
                        arguments: ["node": reference("node")]
                    ))
                )
            ]
        )

        #expect(throws: Never.self) {
            try builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a path fills a word's receiver and is judged like a call")
    func aPathReceiverIsJudgedAtTheLink() throws {
        // Given. `"abc".absolute` and `absolute(of: "abc")` mean the same call,
        // so they refuse on the same surface
        let sut = try Module(
            walked: ["std.math.absolute"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["word": Parameter(type: .string)]
                    ),
                    body: [],
                    result: .reference([.key("word"), .key("absolute")])
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Numeric' does not admit")
        }
    }

    @Test("a path call refuses a parameter read two ways")
    func aPathSendRefusesADisagreeingReading() throws {
        // Given. The receiver's procedure shape fills one parameter twice, and
        // a parameter read as a whole number and as text has no answer on the
        // path surface any more than on the written one
        let sut = try Module(
            procedures: [
                "summed": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .procedure(Signature(
                                parameters: [
                                    "seed": Parameter(type: .parameter(name: "N", constraint: "std.Numeric"))
                                ],
                                returns: .parameter(name: "N", constraint: "std.Numeric")
                            )))
                        ],
                        returns: .parameter(name: "N", constraint: "std.Numeric")
                    ),
                    body: [],
                    result: .literal(.int(0))
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("pair"), expression: .closure(Procedure(
                                signature: Signature(
                                    parameters: ["seed": Parameter(type: .int)],
                                    returns: .string
                                ),
                                body: [],
                                result: .literal(.string("x"))
                            ))
                        )
                    ],
                    result: .reference([.key("pair"), .key("summed")])
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("is read as int and as string")
        }
    }

    @Test("a path cannot reach a word that declares no receiver")
    func aPathDoesNotReachAReceiverlessWord() throws {
        // Given. A pure word without a receiver leaves a path nothing to fill,
        // so the build refuses where the run would have found nothing
        let sut = try Module(
            procedures: [
                "helper": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["word": Parameter(type: .string)]
                    ),
                    body: [],
                    result: .reference([.key("word"), .key("helper")])
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("no word by that name")
        }
    }

    @Test("a word sent through a path is judged like a call")
    func aWordOnAPathIsJudged() throws {
        // Given. Text has no fields, so the name is a word, and the word's
        // bounded receiver refuses the text's reading the way the written call
        // would
        let sut = try Module(
            walked: ["std.math.absolute"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("task"), expression: .literal(.string("a"))
                        )
                    ],
                    result: .reference([.key("task"), .key("absolute")])
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("which 'std.Numeric' does not admit")
        }
    }

    @Test("a dot on a record is a read, and a word there is written as a call")
    func aDotOnARecordDoesNotReachAWord() throws {
        // Given. The record does not declare the name, and a shape with fields
        // reads fields alone: the word by that name is not consulted, and the
        // refusal says to write the call
        let sut = try Module(
            walked: ["std.math.absolute"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("task"), expression: .record(["id": .literal(.string("a"))])
                        )
                    ],
                    result: .reference([.key("task"), .key("absolute")])
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("does not declare")
                && "\(error)".contains("A word is sent with a written call")
        }
    }

    @Test("a receiver written in front and by name is refused")
    func aReceiverAndASameNamedArgumentAreOneSlot() throws {
        // Given. The dot writes the receiver and the arguments write `of`
        // again. One parameter takes one argument, and the one by name would be
        // neither read nor run, so the build refuses the call
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.int(1)),
                        selector: "std.math.absolute",
                        arguments: ["of": .literal(.string("x"))]
                    ))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("both in front and by name")
        }
    }

    @Test("a closure's signature is held to the same judgment as a declaration")
    func aClosureSignatureIsJudgedAtTheLink() throws {
        // Given. Unreached code still has to compile, and a signature written
        // inline is a declaration however deep a body buries it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("kept"), expression: .closure(Procedure(
                                signature: Signature(
                                    parameters: [
                                        "it": Parameter(type: .parameter(name: "T", constraint: "Nope"))
                                    ]
                                ),
                                body: [],
                                result: reference("it")
                            ))
                        )
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("names 'Nope', which no module in this link declares")
        }
    }

    @Test("a receiver naming no parameter refuses where it is declared")
    func aReceiverNamingNoParameterRefuses() throws {
        // Given. The declaration states a fact about its own parameters, and a
        // name pointing at none of them is judged where it is written
        let sut = try Module(
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["word": Parameter(type: .string)]
                    ),
                    body: [],
                    result: reference("word")
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("receiver names 'of'")
        }
    }

    @Test("a declaration sharing a word's bare spelling does not shadow the path")
    func aDeclarationDoesNotShadowAPathWord() async throws {
        // Given. A module's bare `first` lives among the selectors and std's
        // `first` among the path words; one spelling, two questions, two tables
        let sut = try Module(
            walked: ["std.collection.first"],
            procedures: [
                "first": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["items": Parameter(type: .array(.string))],
                        returns: .string
                    ),
                    body: [],
                    result: .reference([.key("items"), .key("first")])
                )
            ]
        )

        // When
        let answered = try await run(
            sut,
            arguments: ["items": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(answered == .string("a"))
    }

    @Test("an effect's own resolver still derives a path's word")
    func anEffectResolverDerivesWords() async throws {
        // Given. A native word resolves its receiver through its invocation,
        // which is the one door outside the executor's own resolvers. The
        // receiver's path ends in a word, so a resolver assembled without the
        // word table would read absence where the build approved a call.
        let sut = try Module(
            walked: ["std.collection.reversed"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["items": Parameter(type: .array(.int))],
                        returns: .array(.int)
                    ),
                    body: [],
                    result: .call(Call(
                        receiver: .reference([.key("items"), .key("reversed")]),
                        selector: "std.concurrent.map",
                        arguments: [
                            "by": .closure(Procedure(
                                signature: Signature(
                                    parameters: ["item": Parameter(type: .int)],
                                    returns: .int
                                ),
                                body: [],
                                result: reference("item")
                            ))
                        ]
                    ))
                )
            ]
        )

        // When
        let answered = try await run(sut, arguments: ["items": .array([.int(1), .int(2)])])

        // Then
        #expect(answered == .array([.int(2), .int(1)]))
    }

    @Test("a hand-built table ends its own membership recursion")
    func aHandBuiltTableTerminates() throws {
        // Given. A table nothing linked, holding the declaration the build would
        // have refused; the table answers rather than chasing it
        let sut = TypeTable(
            constraints: ["Loop": [.parameter(name: "S", constraint: "Loop")]]
        )

        // When / Then
        #expect(
            sut.admits(
                constraint: "Loop",
                reading: .parameter(name: "T", constraint: "Loop")
            ) == true
        )
        let table = sut.shapes
        let loop = try #require(table.constraintRow(named: "Loop"))

        #expect(table.admits(constraint: loop, value: .int(1), assuming: []) == true)
    }

    @Test("a constrained reading fed to a looser bound passes")
    func aConstrainedReadingFitsALooserBound() throws {
        // Given. Inside a generic body the argument reads as the enclosing
        // parameter, and its membership is a subset of what the callee asks
        let sut = try Module(
            constraints: ["Exact": [.int]],
            procedures: [
                "smallest": Procedure(
                    signature: Signature(
                        parameters: [
                            "left": Parameter(type: .parameter(name: "T", constraint: "Exact")),
                            "right": Parameter(type: .parameter(name: "T", constraint: "Exact"))
                        ],
                        returns: .bool
                    ),
                    body: [],
                    result: .call(Call(
                        receiver: reference("left"),
                        selector: "std.math.lessThan",
                        arguments: ["value": reference("right")]
                    ))
                ),
                entryName: Procedure(
                    signature: Signature(returns: .bool),
                    body: [],
                    result: .call(Call(
                        selector: "smallest",
                        arguments: [
                            "left": .literal(.int(1)),
                            "right": .literal(.int(2))
                        ]
                    ))
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try builder.build([sut] + Module.standard, entry: entryName)
        }
    }
}

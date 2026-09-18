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
    func aReadingOutsideTheConstraintRefusesAtTheLink() async throws {
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("arithmetic on two strings refuses at the build")
    func arithmeticOnTwoStringsRefusesAtTheLink() async throws {
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
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
        // the name and the same judgment std's procedures get is this one's
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .parameter(name: "T", constraints: ["Scalar"]))],
                        returns: .parameter(name: "T", constraints: ["Scalar"])
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
    func aDeclaredConstraintRefusesAtItsOwnBound() async throws {
        // Given
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .parameter(name: "T", constraints: ["Scalar"]))],
                        returns: .parameter(name: "T", constraints: ["Scalar"])
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Scalar' does not admit")
        }
    }

    @Test("a signature naming a constraint nobody declares refuses at the build")
    func anUndeclaredConstraintRefusesAtTheLink() async throws {
        // Given. Unreached code still has to compile, and a bound naming
        // nothing is a defect whether or not a call ever fills it
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .parameter(name: "T", constraints: ["Sortable"]))],
                        returns: .parameter(name: "T", constraints: ["Sortable"])
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("names 'Sortable', which no module in this link declares")
        }
    }

    @Test("one name whose occurrences carry different bounds refuses at the build")
    func twoBoundsOnOneNameRefuseAtTheBuild() async throws {
        // Given. The bound is written inline, so two slots writing different
        // bounds for one name are two claims about one thing
        let sut = try Module(
            constraints: ["A": [.int], "B": [.string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "left": Parameter(type: .parameter(name: "T", constraints: ["A"])),
                            "right": Parameter(type: .parameter(name: "T", constraints: ["B"]))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(signature: Signature(), body: [], result: .literal(.int(1)))
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("One name is held to one set of bounds")
        }
    }

    @Test("a composition inside a slot is held to its bounds where the call is written")
    func aNestedCompositionIsJudgedAtTheBuild() async throws {
        // Given. `A` admits int and string, `B` admits string alone, and the
        // slot takes a list of what belongs to both
        func module(handing element: Value) throws -> Module {
            try Module(
                constraints: ["A": [.int, .string], "B": [.string]],
                procedures: [
                    "keep": Procedure(
                        signature: Signature(
                            parameters: ["items": Parameter(type: .array(.composition(["A", "B"])))],
                            returns: .int
                        ),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "keep", arguments: ["items": .literal(.array([element]))]))
                    )
                ]
            )
        }

        // When / Then
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard, entry: entryName)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("which 'B' does not admit")
        }
    }

    @Test("a member that is a composition or a contract is not a concrete type")
    func aCompositionIsNotAMember() async throws {
        // Given
        let sut = try Module(
            constraints: ["A": [.int], "B": [.string], "Loop": [.composition(["A", "B"])]],
            procedures: [entryName: Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("a member is a concrete type")
        }
    }

    @Test("a composition a declaration promises holds the answer to its bounds")
    func aPromisedCompositionIsJudgedAtTheBuild() async throws {
        // Given. `A` admits int and string, `B` admits string alone, and the
        // declaration promises what belongs to both while answering a whole number
        let sut = try Module(
            constraints: ["A": [.int, .string], "B": [.string]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .composition(["A", "B"])),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("promises A & B")
        }
    }

    @Test("a name declared as a composition holds only what every bound admits")
    func aDeclaredCompositionIsJudgedAtTheBuild() async throws {
        // Given
        let sut = try Module(
            constraints: ["A": [.int, .string], "B": [.string]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .constant("held", declared: .composition(["A", "B"])),
                            expression: .literal(.int(5))
                        )
                    ],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("holds A & B")
        }
    }

    @Test("a value of a composition fits only a slot one of every membership's members fits")
    func aCompositionValueIsHeldWhereItGoes() async throws {
        // Given. `it` belongs to `A`, whose members are int and string, and is
        // handed to a slot that takes bool
        let sut = try Module(
            constraints: ["A": [.int, .string]],
            procedures: [
                "flag": Procedure(
                    signature: Signature(parameters: ["on": Parameter(type: .bool)], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .composition(["A"]))], returns: .int),
                    body: [],
                    result: .call(Call(selector: "flag", arguments: ["on": reference("it")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
        }
    }

    @Test("a promise mentioning one parameter twice is answered the same both times")
    func aPromiseReadTwoWaysRefuses() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .record(["a": .parameter(name: "T"), "b": .parameter(name: "T")])),
                    body: [],
                    result: .record(["a": .literal(.int(1)), "b": .literal(.string("x"))])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("is answered as int and as string")
        }
    }

    @Test("a membership reaching a composition that names it back is asked once")
    func aRingThroughACompositionEnds() async throws {
        // Given. `A` admits a list of `X`, and `X` is what belongs to `A` and `B`
        let sut = try Module(
            types: ["X": .composition(["A", "B"])],
            constraints: ["A": [.array(.named("X"))], "B": [.string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(parameters: ["of": Parameter(type: .named("A"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .named("X"))], returns: .int),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: ["of": reference("it")]))
                )
            ]
        )

        // When / Then. Refused or built, and the asking ends
        _ = try? await builder.build([sut] + Module.standard, entry: entryName)
    }

    @Test("null is not a value of a contract standing as a type")
    func nullIsRefusedWhereAContractStands() async throws {
        // Given
        let sut = try Module(
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            procedures: [
                "app.tell": Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .named("app.Describable"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "app.tell", arguments: ["it": .literal(.null)]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
        }
    }

    @Test("a contract named in a contract's own signature holds the witness to it")
    func aContractInItsOwnSignatureIsJudged() async throws {
        // Given. `describe` promises what answers the contract, and the
        // witness answers a whole number
        let sut = try Module(
            types: ["bank.Card": .record(["last": .string])],
            contracts: ["app.Describable": ["describe": Signature(returns: .named("app.Describable"))]],
            claims: ["bank.Card": ["app.Describable"]],
            procedures: [
                "bank.Card.describe": Procedure(
                    signature: Signature(receiver: "of", parameters: ["of": Parameter(type: .named("bank.Card"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .constant("card"),
                            expression: .cast(.record(["last": .literal(.string("x"))]), as: .named("bank.Card"), optional: false)
                        )
                    ],
                    result: .call(Call(receiver: reference("card"), selector: "app.Describable.describe"))
                )
            ]
        )

        // When / Then. The claim is leaned on, and what is behind it is wrong
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("where the contract writes")
        }
    }

    @Test("a parameter bounded by two memberships takes only what both admit")
    func twoBoundsOnOneParameterBothHold() async throws {
        // Given. `A` admits int and string, `B` admits string alone, and `T`
        // is bounded by both
        func module(handing argument: Value) throws -> Module {
            try Module(
                constraints: ["A": [.int, .string], "B": [.string]],
                procedures: [
                    "keep": Procedure(
                        signature: Signature(
                            parameters: ["left": Parameter(type: .parameter(name: "T", constraints: ["A", "B"]))],
                            returns: .int
                        ),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "keep", arguments: ["left": .literal(argument)]))
                    )
                ]
            )
        }

        // When / Then. A string is inside both; a whole number is outside `B`
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard, entry: entryName)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("which 'B' does not admit")
        }
    }

    @Test("a bare mention and a bounded mention are one bounded parameter")
    func aBareMentionRidesTheBoundedOne() async throws {
        // Given. A bounded `some T` in one slot and a bare one in another are
        // one parameter bounded once, so the bound judges both readings
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "left": Parameter(type: .parameter(name: "T", constraints: ["Scalar"])),
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Scalar' does not admit")
        }
    }

    @Test("a name cannot be a type and a constraint at once")
    func aNameDeclaredAsTypeAndConstraintRefuses() async throws {
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("both a type and a constraint")
        }
    }

    @Test("a constraint admitting nothing refuses at the build")
    func anEmptyConstraintRefusesAtTheLink() async throws {
        // Given. No parameter it bounds could ever be filled, which is the same
        // fact an empty enum states
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    @Test("a type parameter hidden in a declared type refuses at the build")
    func aParameterInADeclaredTypeRefusesAtTheLink() async throws {
        // Given. A declared type has no call to fill a parameter, and a bound
        // hidden behind the name would otherwise escape every judgment
        let sut = try Module(
            types: ["Weird": .parameter(name: "T", constraints: ["Sortable"])],
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a parameter behind a procedure type in a declared type refuses too")
    func aParameterInADeclaredProcedureTypeRefusesAtTheLink() async throws {
        // Given. A declared type is not a filling site however deep the
        // parameter hides: nothing ever binds it, so the claim would go
        // unjudged everywhere
        let sut = try Module(
            types: [
                "Callback": .procedure(
                    Signature(
                        parameters: ["it": Parameter(type: .parameter(name: "T", constraints: ["Scalar"]))]
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a name that reaches only names refuses at the build")
    func aNameOnlyCycleRefusesAtTheLink() async throws {
        // Given. A type may name itself through a type, and a name that only
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
            await #expect {
                try await builder.build([sut] + Module.standard, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("through nothing but names")
            }
        }

        // A recursive type passes: the name reaches a type on the way back.
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

        await #expect(throws: Never.self) {
            try await builder.build([tree] + Module.standard, entry: entryName)
        }
    }

    @Test("a constraint member is a concrete type")
    func aConstraintMemberMustBeConcrete() async throws {
        // Given. `some` in member position stands for a type and names none;
        // admitting it would also let a membership chase itself forever
        for member in [TypeExpression.parameter(name: "S", constraints: ["Loop"]), .any, .never] {
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
            await #expect {
                try await builder.build([sut] + Module.standard, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("a member is a concrete type")
            }
        }
    }

    @Test("a enum no member of the bound can spell refuses at the build")
    func aOneOfOutsideTheBoundRefusesAtTheLink() async throws {
        // Given. Procedures on a Numeric slot: no member of the constraint can spell
        // them, so no call could ever fit this parameter
        let sut = try Module(
            procedures: [
                "pick": Procedure(
                    signature: Signature(
                        parameters: [
                            "speed": Parameter(
                                type: .parameter(name: "N", constraints: ["std.Numeric"]),
                                candidates: ["fast", "slow"]
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("enum admits nothing")
        }
    }

    @Test("a fraction candidate is judged by the fraction's one spelling")
    func aFractionCandidateIsJudgedByItsSpelling() async throws {
        // Given. A fraction spells with its point, so `1` on a double slot is
        // the int's spelling and a member no fraction could ever match, and
        // `1e0`/`1.00` are second spellings of a fraction that has one
        func module(candidates candidates: [String]) async throws -> Module {
            try Module(
                procedures: [
                    entryName: Procedure(
                        signature: Signature(
                            parameters: [
                                "level": Parameter(type: .double, candidates: candidates)
                            ]
                        ),
                        body: [],
                        result: .literal(.null)
                    )
                ]
            )
        }

        for dead in ["1", "1e0", "1.50", "1e-5"] {
            await #expect("\(dead)") {
                try await builder.build([module(candidates: ["2.0", dead])] + Module.standard, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("'\(dead)'")
            }
        }

        // The spellings a document itself writes are alive. The exponent form
        // included, sign and padding and all.
        await #expect(throws: Never.self) {
            try await builder.build([module(candidates: ["1.0", "1.5", "1e-05"])] + Module.standard, entry: entryName)
        }
    }

    @Test("enum membership is the number's worth, not its bit pattern")
    func aOneOfMeetsANumberByWorth() async throws {
        // Given. The two zeros are one worth in the language's own order, so a
        // list that writes one admits the other
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: [
                            "level": Parameter(type: .double, candidates: ["0.0", "1.5"])
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
                                type: .parameter(name: "N", constraints: ["std.Numeric"]),
                                candidates: ["1", "2.5"]
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

    @Test("a member hiding a refused type behind a name still refuses")
    func aMemberBehindANameIsJudgedResolved() async throws {
        // Given. An alias is a name for a type, so what the type may not be
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("a member is a concrete type")
        }
    }

    @Test("a recursive type compared with itself agrees instead of recursing")
    func aRecursiveTypeAcceptsItself() async throws {
        // Given. A type that names itself walks back into the comparison it is
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

        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a dot on a record is a read, and a procedure there is written as a call")
    func aDotOnARecordDoesNotReachAProcedure() async throws {
        // Given. The record does not declare the name, and a type with fields
        // reads fields alone: the procedure by that name is not consulted, and the
        // refusal says to write the call
        let sut = try Module(
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("does not declare")
                && "\(error)".contains("A procedure is sent with a written call")
        }
    }

    @Test("a dot on a type with no fields says to write the call")
    func aDotOnAFieldlessTypeSaysToWriteTheCall() async throws {
        // Given. Text has no name to read, so the refusal names the one
        // spelling that reaches the procedure: the written call
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("task"), expression: .literal(.string("a"))
                        )
                    ],
                    result: .reference([.key("task"), .key("count")])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("string has no name there to read")
                && "\(error)".contains("sent with a written call")
        }
    }

    @Test("a receiver written in front and by name is refused")
    func aReceiverAndASameNamedArgumentAreOneSlot() async throws {
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("both in front and by name")
        }
    }

    @Test("a closure's signature is held to the same judgment as a declaration")
    func aClosureSignatureIsJudgedAtTheLink() async throws {
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
                                        "it": Parameter(type: .parameter(name: "T", constraints: ["Nope"]))
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
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("names 'Nope', which no module in this link declares")
        }
    }

    @Test("a receiver naming no parameter refuses where it is declared")
    func aReceiverNamingNoParameterRefuses() async throws {
        // Given. The declaration states a fact about its own parameters, and a
        // name pointing at none of them is judged where it is written
        let sut = try Module(
            procedures: [
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: ["procedure": Parameter(type: .string)]
                    ),
                    body: [],
                    result: reference("procedure")
                ),
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("receiver names 'of'")
        }
    }

    @Test("an effect's own resolver reads the receiver it was handed")
    func anEffectResolverReadsItsReceiver() async throws {
        // Given. A native procedure resolves its receiver through its invocation,
        // which is the one door outside the executor's own resolvers.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["items": Parameter(type: .array(.int))],
                        returns: .array(.int)
                    ),
                    body: [],
                    result: .call(Call(
                        receiver: .call(Call(receiver: reference("items"), selector: "std.collection.reversed")),
                        selector: "std.concurrent.map",
                        arguments: [
                            "by": .closure(Procedure(
                                signature: Signature(
                                    parameters: [
                                        "index": Parameter(type: .int),
                                        "item": Parameter(type: .int)
                                    ],
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
            constraints: ["Loop": [.parameter(name: "S", constraints: ["Loop"])]]
        )

        // When / Then
        #expect(
            sut.admits(
                constraint: "Loop",
                reading: .parameter(name: "T", constraints: ["Loop"])
            ) == true
        )
        let table = sut.loweredTypes
        let loop = try #require(table.constraintRow(named: "Loop"))

        #expect(table.admits(constraint: loop, value: .int(1), assuming: []) == true)
    }

    @Test("a constrained reading fed to a looser bound passes")
    func aConstrainedReadingFitsALooserBound() async throws {
        // Given. Inside a generic body the argument reads as the enclosing
        // parameter, and its membership is a subset of what the callee asks
        let sut = try Module(
            constraints: ["Exact": [.int]],
            procedures: [
                "smallest": Procedure(
                    signature: Signature(
                        parameters: [
                            "left": Parameter(type: .parameter(name: "T", constraints: ["Exact"])),
                            "right": Parameter(type: .parameter(name: "T", constraints: ["Exact"]))
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
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard, entry: entryName)
        }
    }
}

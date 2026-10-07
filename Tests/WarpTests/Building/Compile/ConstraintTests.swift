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
import WarpTestSupport

// A constraint is a declared membership, and a bounded `some T` takes only what
// the membership admits. These are the places the bound turns a reading into a
// refusal before anything runs, and the one place it waits for the run, because
// the text said nothing.
@Suite("What a bounded type parameter admits")
struct ConstraintTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a reading outside the constraint refuses at the build")
    func aReadingOutsideTheConstraintRefusesAtTheBuild() async throws {
        // Given. Both sides of `lessThan` are booleans, and `Comparable` admits
        // none of them. The reading is a literal, so the build can see it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .bool),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Math.lessThan",
                        arguments: [.literal(.bool(true)), .literal(.bool(false))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Standard.Comparable' does not admit")
        }
    }

    @Test("arithmetic on two strings refuses at the build")
    func arithmeticOnTwoStringsRefusesAtTheBuild() async throws {
        // Given. The two sides agree, so the one type parameter reads one
        // thing. Agreement is not admission: `Numeric` does not admit text.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Math.plus",
                        arguments: [.literal(.string("a")), .literal(.string("b"))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Standard.Numeric' does not admit")
        }
    }

    @Test("a value arriving through any is judged at the boundary")
    func aValueArrivingThroughAnyIsJudgedAtTheBoundary() async throws {
        // Given. The parameter is declared `any`, so the build reads nothing and
        // the membership is judged where the value arrives
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "left", type: .any)],
                        returns: .bool
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Math.lessThan",
                        arguments: [reference("left"), .literal(.int(1))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, arguments: ["left": .bool(true)])
        } throws: { error in
            "\(error)".contains("nothing 'Standard.Comparable' admits takes bool")
        }
    }

    @Test("a module declares a constraint of its own and the bound holds")
    func aModuleDeclaresAConstraintOfItsOwn() async throws {
        // Given. The membership lives in the declaration, so a signature writes
        // the name and the same judgment Standard's procedures get is this one's
        let sut = try Module(
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T", constraints: ["Scalar"]))],
                        returns: .parameter(name: "T", constraints: ["Scalar"])
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [.literal(.int(7))]))
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
                        parameters: [Parameter(name: "value", type: .parameter(name: "T", constraints: ["Scalar"]))],
                        returns: .parameter(name: "T", constraints: ["Scalar"])
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [.literal(.double(1.5))]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Scalar' does not admit")
        }
    }

    @Test("a signature naming a constraint nobody declares refuses at the build")
    func anUndeclaredConstraintRefusesAtTheBuild() async throws {
        // Given. Unreached code still has to compile, and a bound naming
        // nothing is a defect whether or not a call ever fills it
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T", constraints: ["Sortable"]))],
                        returns: .parameter(name: "T", constraints: ["Sortable"])
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
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
                            Parameter(name: "left", type: .parameter(name: "T", constraints: ["A"])),
                            Parameter(name: "right", type: .parameter(name: "T", constraints: ["B"]))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(access: .public, signature: Signature(), body: [], result: .literal(.int(1)))
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
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
                            parameters: [Parameter(name: "items", type: .array(.composition(["A", "B"])))],
                            returns: .int
                        ),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "keep", arguments: [.literal(.array([element]))]))
                    )
                ]
            )
        }

        // When / Then
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which 'B' does not admit")
        }
    }

    @Test("a member that is a composition or a contract is not a concrete type")
    func aCompositionIsNotAMember() async throws {
        // Given
        let sut = try Module(
            constraints: ["A": [.int], "B": [.string], "Loop": [.composition(["A", "B"])]],
            procedures: [entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
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
                    access: .public,
                    signature: Signature(returns: .composition(["A", "B"])),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
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
                    access: .public,
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
            try await builder.build([sut] + Module.standard)
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
                    signature: Signature(parameters: [Parameter(name: "on", type: .bool)], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .composition(["A"]))], returns: .int),
                    body: [],
                    result: .call(Call(selector: "flag", arguments: [reference("it")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("with on, which holds A where bool is declared")
        }
    }

    @Test("a type parameter a promise names is answered by that parameter alone")
    func aPromisedParameterIsAnsweredByItself() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .record(["a": .parameter(name: "T"), "b": .parameter(name: "T")])),
                    body: [],
                    result: .record(["a": .literal(.int(1)), "b": .literal(.string("x"))])
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("answers { a: int, b: string }, and its declaration promises")
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
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("A"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("X"))], returns: .int),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [reference("it")]))
                )
            ]
        )

        // When / Then. It builds, and the asking ends
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard)
        }
    }

    @Test("null is not a value of a contract standing as a type")
    func nullIsRefusedWhereAContractStands() async throws {
        // Given
        let sut = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .string)]],
            procedures: [
                "App.tell": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .named("App.Describable"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "App.tell", arguments: [.literal(.null)]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'it' holds null, which does not answer every procedure")
        }
    }

    @Test("a contract named in a contract's own signature holds the witness to it")
    func aContractInItsOwnSignatureIsJudged() async throws {
        // Given. `describe` promises what answers the contract, and the
        // witness answers a whole number
        let sut = try Module(
            types: ["Bank.Card": .record(["last": .string])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .array(.named("App.Describable")))]],
            claims: ["Bank.Card": ["App.Describable"]],
            procedures: [
                "Bank.Card.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("Bank.Card"))], returns: .array(.int)),
                    body: [],
                    result: .array([.literal(.int(1))])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [
                        Statement(
                            binding: .constant("card"),
                            expression: .cast(.record(["last": .literal(.string("x"))]), as: .named("Bank.Card"), optional: false)
                        )
                    ],
                    result: .call(Call(selector: "App.Describable.describe", arguments: [reference("card")]))
                )
            ]
        )

        // When / Then. The claim is leaned on, and what is behind it is wrong
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("where the contract writes")
        }
    }

    @Test("a claim leaning on a claim that fell falls with it")
    func aClaimLeaningOnAFallenClaimFalls() async throws {
        // Given. `Box` answers `Printable` by showing a `Card`, `Card` claims
        // `Describable` and answers nothing it asks
        let sut = try Module(
            types: ["App.Box": .record(["n": .int]), "Bank.Card": .record(["last": .string])],
            contracts: [
                "App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .string)],
                "App.Printable": ["show": Signature(parameters: [Parameter(name: "of", type: .named("App.Printable"))], returns: .named("App.Describable"))]
            ],
            claims: ["Bank.Card": ["App.Describable"], "App.Box": ["App.Printable"]],
            procedures: [
                "App.Box.show": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("App.Box"))], returns: .named("Bank.Card")),
                    body: [],
                    result: .cast(.record(["last": .literal(.string("x"))]), as: .named("Bank.Card"), optional: false)
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            binding: .constant("box"),
                            expression: .cast(.record(["n": .literal(.int(1))]), as: .named("App.Box"), optional: false)
                        ),
                        Statement(
                            binding: .constant("shown"),
                            expression: .call(Call(selector: "App.Printable.show", arguments: [reference("box")]))
                        )
                    ],
                    result: .call(Call(selector: "App.Describable.describe", arguments: [reference("shown")]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("answers Bank.Card where the contract writes App.Describable")
        }
    }

    @Test("null fills a nullable composition whole")
    func nullFillsANullableComposition() async throws {
        // Given
        let sut = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .string)]],
            procedures: [
                "App.tell": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .nullable(.named("App.Describable")))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "App.tell", arguments: [.literal(.null)]))
                )
            ]
        )

        // When / Then
        _ = try await builder.build([sut] + Module.standard)
    }

    @Test("a type handed on once answers no contract")
    func aLinearTypeAnswersNoContract() async throws {
        // Given. A contract standing where a type is written holds a value
        // under no name, and nothing follows a value handed on once but the
        // name that holds it
        let sut = try Module(
            types: ["App.Handle": .linear(.record(["name": .string]))],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .named("App.Describable"))], returns: .string)]],
            claims: ["App.Handle": ["App.Describable"]],
            procedures: [
                "App.Handle.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .borrowing(.named("App.Handle")))], returns: .string),
                    body: [],
                    result: .literal(.string("a handle"))
                ),
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("is handed on once and answers no contract")
        }
    }

    @Test("a contract's procedure holds one name to one set of bounds")
    func aContractProcedureHoldsOneNameToOneSet() async throws {
        // Given. The contract's procedure bounds `T` by `A` in one slot and
        // by `B` in another, which is two claims about one name
        let sut = try Module(
            constraints: ["A": [.int, .string], "B": [.string]],
            contracts: [
                "App.Pairing": [
                    "pair": Signature(
                        parameters: [
                            Parameter(name: "of", type: .named("App.Pairing")),
                            Parameter(name: "left", type: .parameter(name: "T", constraints: ["A"])),
                            Parameter(name: "right", type: .parameter(name: "T", constraints: ["B"]))
                        ],
                        returns: .int
                    )
                ]
            ],
            procedures: [entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("`some T` is bounded by A in one place and B in another")
        }
    }

    @Test("a name bound three ways is refused by the two sets first in name order")
    func aNameBoundThreeWaysIsRefusedByItsTwoLeastSets() async throws {
        // Given. `T` is bound by `A`, `B` and `C` in three slots, so which
        // two the sentence names is fixed by name order and not by the walk
        let sut = try Module(
            constraints: ["A": [.int], "B": [.string], "C": [.bool]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "x", type: .parameter(name: "T", constraints: ["C"])),
                            Parameter(name: "y", type: .parameter(name: "T", constraints: ["B"])),
                            Parameter(name: "z", type: .parameter(name: "T", constraints: ["A"]))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("`some T` is bounded by A in one place and B in another")
        }
    }

    @Test("a parameter names its bounds once each and in name order", arguments: [["B", "A"], ["A", "A"]] as [[Name]])
    func aParameterNamesItsBoundsInOrder(bounds: [Name]) async throws {
        // Given. A signature assembled with `B & A`, which no reader writes
        let sut = try Module(
            constraints: ["A": [.int, .string], "B": [.string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "left", type: .parameter(name: "T", constraints: bounds))],
                        returns: .int
                    ),
                    body: [],
                    result: .literal(.int(1))
                ),
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("`some T` names its bounds once each and in name order")
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
                            parameters: [Parameter(name: "left", type: .parameter(name: "T", constraints: ["A", "B"]))],
                            returns: .int
                        ),
                        body: [],
                        result: .literal(.int(1))
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "keep", arguments: [.literal(argument)]))
                    )
                ]
            )
        }

        // When / Then. A string is inside both; a whole number is outside `B`
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard)
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
                            Parameter(name: "left", type: .parameter(name: "T", constraints: ["Scalar"])),
                            Parameter(name: "right", type: .parameter(name: "T"))
                        ]
                    ),
                    body: [],
                    result: .literal(.null)
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [.literal(.double(1.0)), .literal(.double(2.0))]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
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
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("both a type and a constraint")
        }
    }

    @Test("a constraint admitting nothing refuses at the build")
    func anEmptyConstraintRefusesAtTheBuild() async throws {
        // Given. No parameter it bounds could ever be filled, which is the same
        // fact an empty enum states
        let sut = try Module(
            constraints: ["Nothing": []],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("admits nothing")
        }
    }

    @Test("a type parameter hidden in a declared type refuses at the build")
    func aParameterInADeclaredTypeRefusesAtTheBuild() async throws {
        // Given. A declared type has no call to fill a parameter, and a bound
        // hidden behind the name would otherwise escape every judgment
        let sut = try Module(
            types: ["Weird": .parameter(name: "T", constraints: ["Sortable"])],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .named("Weird"))]
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a parameter behind a procedure type in a declared type refuses too")
    func aParameterInADeclaredProcedureTypeRefusesAtTheBuild() async throws {
        // Given. A declared type is not a filling site however deep the
        // parameter hides: nothing ever binds it, so the claim would go
        // unjudged everywhere
        let sut = try Module(
            types: [
                "Callback": .procedure(ProcedureType(
                    parameters: [.parameter(name: "T", constraints: ["Scalar"])]
                ))
            ],
            constraints: ["Scalar": [.int, .string]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("A type parameter lives in a signature")
        }
    }

    @Test("a name that reaches only names refuses at the build")
    func aNameOnlyCycleRefusesAtTheBuild() async throws {
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
                        access: .public,
                        signature: Signature(),
                        body: [],
                        result: .literal(.int(1))
                    )
                ]
            )

            // When / Then
            await #expect {
                try await builder.build([sut] + Module.standard)
            } throws: { error in
                error is BuildError && "\(error)".contains("through nothing but names")
            }
        }

        // A recursive type passes: the name reaches a type on the way back.
        let tree = try Module(
            types: ["Tree": .record(["children": .array(.named("Tree"))])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        await #expect(throws: Never.self) {
            try await builder.build([tree] + Module.standard)
        }
    }

    @Test("a constraint member is a concrete type", arguments: [
        TypeExpression.parameter(name: "S", constraints: ["Loop"]), .any, .never
    ])
    func aConstraintMemberMustBeConcrete(member: TypeExpression) async throws {
        // Given. `some` in member position stands for a type and names none;
        // admitting it would also let a membership chase itself forever
        let sut = try Module(
            constraints: ["Loop": [member]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("a member is a concrete type")
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
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("a member is a concrete type")
        }
    }

    @Test("a closure's signature is held to the same judgment as a declaration")
    func aClosureSignatureIsJudgedAtTheBuild() async throws {
        // Given. Unreached code still has to compile, and a signature written
        // inline is a declaration however deep a body buries it
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("kept"), expression: .closure(Procedure(
                                signature: Signature(
                                    parameters: [
                                        Parameter(name: "it", type: .parameter(name: "T", constraints: ["Nope"]))
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
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("names 'Nope', which no module in this link declares")
        }
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
                            Parameter(name: "left", type: .parameter(name: "T", constraints: ["Exact"])),
                            Parameter(name: "right", type: .parameter(name: "T", constraints: ["Exact"]))
                        ],
                        returns: .bool
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Math.lessThan",
                        arguments: [reference("left"), reference("right")]
                    ))
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .bool),
                    body: [],
                    result: .call(Call(selector: "smallest", arguments: [.literal(.int(1)), .literal(.int(2))]))
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard)
        }
    }

    @Test("sorting what Comparable does not admit refuses at the build")
    func sortingTheUnorderableRefuses() async throws {
        // Given. `sorted` is bounded by `Standard.Comparable`, and
        // booleans are a reading the build can see
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Collection.sorted",
                        arguments: [.literal(.array([.bool(true), .bool(false)]))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Standard.Comparable' does not admit")
        }
    }

    @Test("min handed null first is held to the parameter it declares first")
    func minHandedNullIsHeldToItsFirstParameter() async throws {
        // Given. The first argument is a reference that reads null. Null is a
        // value, and `some T: Comparable` does not admit one, so the boundary
        // refuses before the ordering procedure is asked anything
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "absent", type: .any)]
                    ),
                    body: [],
                    result: .call(Call(selector: "Standard.Math.min", arguments: [reference("absent"), .literal(.int(1))]))
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, arguments: ["absent": .null])
        } throws: { error in
            "\(error)".contains("input 'lhs': expected some T: Standard.Comparable, got null")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

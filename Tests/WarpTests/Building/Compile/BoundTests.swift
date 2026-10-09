//
//  BoundTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard
import WarpTestSupport

// A bounded `some T` takes only what answers every contract it is bounded by.
// These are the places the bound turns a reading into a refusal before anything
// runs, and the one place it waits for the run, because the text said nothing.
@Suite("What a bounded type parameter takes")
struct BoundTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a reading outside the bound refuses at the build")
    func aReadingOutsideTheBoundRefusesAtTheBuild() async throws {
        // Given. Both sides of `lessThan` are booleans, and no claim puts them
        // under `Comparable`. The reading is a literal, so the build can see it.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .bool),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Comparable.lessThan",
                        arguments: [.literal(.bool(true)), .literal(.bool(false))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no document in this link says 'Bool' answers it")
        }
    }

    @Test("arithmetic on two strings refuses at the build")
    func arithmeticOnTwoStringsRefusesAtTheBuild() async throws {
        // Given. The two sides agree, so the one type parameter reads one
        // thing. Agreement is not answering: no claim puts text under `Numeric`.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Numeric.plus",
                        arguments: [.literal(.string("a")), .literal(.string("b"))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no document in this link says 'String' answers it")
        }
    }

    @Test("a value arriving through any is judged at the boundary")
    func aValueArrivingThroughAnyIsJudgedAtTheBoundary() async throws {
        // Given. The parameter is declared `Any`, so the build reads nothing and
        // the contract is judged where the value arrives
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
                        selector: "Standard.Comparable.lessThan",
                        arguments: [reference("left"), .literal(.int(1))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut, arguments: ["left": .bool(true)])
        } throws: { error in
            "\(error)".contains("is sent to 'Bool', which answers no procedure of 'Standard.Comparable'")
        }
    }

    @Test("a module declares a contract of its own and the bound holds")
    func aModuleDeclaresAContractOfItsOwn() async throws {
        // Given. What answers the contract is what the claims say, so a
        // signature writes the name and the same judgment Standard's
        // procedures get is this one's
        let sut = try Module(
            contracts: Self.markers("Scalar"),
            claims: ["Int": ["Scalar"], "String": ["Scalar"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T", bounds: ["Scalar"]))],
                        returns: .parameter(name: "T", bounds: ["Scalar"])
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

    @Test("a reading whose type answers no declared contract refuses at the build")
    func aDeclaredContractRefusesAtItsOwnBound() async throws {
        // Given
        let sut = try Module(
            contracts: Self.markers("Scalar"),
            claims: ["Int": ["Scalar"], "String": ["Scalar"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T", bounds: ["Scalar"]))],
                        returns: .parameter(name: "T", bounds: ["Scalar"])
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
            error is BuildError && "\(error)".contains("no document in this link says 'Double' answers it")
        }
    }

    @Test("a signature naming a contract nobody declares refuses at the build")
    func anUndeclaredContractRefusesAtTheBuild() async throws {
        // Given. Unreached code still has to compile, and a bound naming
        // nothing is a defect whether or not a call ever fills it
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T", bounds: ["Sortable"]))],
                        returns: .parameter(name: "T", bounds: ["Sortable"])
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
            contracts: Self.markers("A", "B"),
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "left", type: .parameter(name: "T", bounds: ["A"])),
                            Parameter(name: "right", type: .parameter(name: "T", bounds: ["B"]))
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
        // Given. Int answers `A`, String answers `A` and `B`, and the slot
        // takes a list of what answers both
        func module(handing element: Value) throws -> Module {
            try Module(
                contracts: Self.markers("A", "B"),
                claims: ["Int": ["A"], "String": ["A", "B"]],
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
            error is BuildError && "\(error)".contains("no document in this link says 'Int' answers it")
        }
    }

    @Test("a composition a declaration promises holds the answer to its bounds")
    func aPromisedCompositionIsJudgedAtTheBuild() async throws {
        // Given. Int answers `A`, String answers `A` and `B`, and the
        // declaration promises what answers both while answering a whole number
        let sut = try Module(
            contracts: Self.markers("A", "B"),
            claims: ["Int": ["A"], "String": ["A", "B"]],
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
            error is BuildError && "\(error)".contains("hands 'Int' where 'B' is asked")
        }
    }

    @Test("a name declared as a composition holds only what answers every bound")
    func aDeclaredCompositionIsJudgedAtTheBuild() async throws {
        // Given
        let sut = try Module(
            contracts: Self.markers("A", "B"),
            claims: ["Int": ["A"], "String": ["A", "B"]],
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
            error is BuildError && "\(error)".contains("hands 'Int' where 'B' is asked")
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
            error is BuildError && "\(error)".contains("answers { a: Int, b: String }, and its declaration promises")
        }
    }

    @Test("null is refused where a contract stands and no document claims it for Null")
    func nullIsRefusedWhereAContractStands() async throws {
        // Given
        let sut = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
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
            error is BuildError && "\(error)".contains("no document in this link says 'Null' answers it")
        }
    }

    @Test("a contract named in a contract's own signature holds the witness to it")
    func aContractInItsOwnSignatureIsJudged() async throws {
        // Given. `describe` promises what answers the contract, and the
        // witness answers a whole number
        let sut = try Module(
            types: ["Bank.Card": .record(["last": .string])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .array(.named("App.Describable")))]],
            claims: ["Bank.Card": ["App.Describable"]],
            procedures: [
                "Bank.Card.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("Bank.Card"))], returns: .array(.int)),
                    body: [],
                    result: .array([.literal(.int(1))])
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.named("App.Describable"))),
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
                "App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)],
                "App.Printable": ["show": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .named("App.Describable"))]
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
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
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

    @Test("a name for a procedure type takes a value read as a contract only through a cast")
    func aNameForAProcedureTypeTakesNoContractValue() async throws {
        // Given. A slot of a type takes a value read as a contract only
        // through a cast, and a name standing for a procedure type is such a
        // slot
        let sut = try Module(
            types: ["App.Pick": .procedure(ProcedureType(parameters: [.int], returns: .int))],
            contracts: Self.markers("App.Marked"),
            claims: ["Int": ["App.Marked"]],
            procedures: [
                "App.take": Procedure(
                    signature: Signature(parameters: [Parameter(name: "p", type: .named("App.Pick"))], returns: .int),
                    body: [],
                    result: .literal(.int(1))
                ),
                "App.hand": Procedure(
                    signature: Signature(parameters: [Parameter(name: "x", type: .named("App.Marked"))], returns: .int),
                    body: [],
                    result: .call(Call(selector: "App.take", arguments: [reference("x")]))
                ),
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: .call(Call(selector: "App.hand", arguments: [.literal(.int(1))])))
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which holds App.Marked where App.Pick is declared")
        }
    }

    @Test("a contract's procedure holds one name to one set of bounds")
    func aContractProcedureHoldsOneNameToOneSet() async throws {
        // Given. The contract's procedure bounds `T` by `A` in one slot and
        // by `B` in another, which is two claims about one name
        let sut = try Module(
            contracts: Self.markers("A", "B").merging([
                "App.Pairing": [
                    "pair": Signature(
                        parameters: [
                            Parameter(name: "of", type: .selfType),
                            Parameter(name: "left", type: .parameter(name: "T", bounds: ["A"])),
                            Parameter(name: "right", type: .parameter(name: "T", bounds: ["B"]))
                        ],
                        returns: .int
                    )
                ]
            ]) { held, _ in held },
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
            contracts: Self.markers("A", "B", "C"),
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "x", type: .parameter(name: "T", bounds: ["C"])),
                            Parameter(name: "y", type: .parameter(name: "T", bounds: ["B"])),
                            Parameter(name: "z", type: .parameter(name: "T", bounds: ["A"]))
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
            contracts: Self.markers("A", "B"),
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "left", type: .parameter(name: "T", bounds: bounds))],
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

    @Test("a parameter bounded by two contracts takes only what answers both")
    func twoBoundsOnOneParameterBothHold() async throws {
        // Given. Int answers `A`, String answers `A` and `B`, and `T` is
        // bounded by both
        func module(handing argument: Value) throws -> Module {
            try Module(
                contracts: Self.markers("A", "B"),
                claims: ["Int": ["A"], "String": ["A", "B"]],
                procedures: [
                    "keep": Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "left", type: .parameter(name: "T", bounds: ["A", "B"]))],
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

        // When / Then. A string answers both; a whole number does not answer `B`
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no document in this link says 'Int' answers it")
        }
    }

    @Test("a bare mention and a bounded mention are one bounded parameter")
    func aBareMentionRidesTheBoundedOne() async throws {
        // Given. A bounded `some T` in one slot and a bare one in another are
        // one parameter bounded once, so the bound judges both readings
        let sut = try Module(
            contracts: Self.markers("Scalar"),
            claims: ["Int": ["Scalar"], "String": ["Scalar"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "left", type: .parameter(name: "T", bounds: ["Scalar"])),
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
            error is BuildError && "\(error)".contains("no document in this link says 'Double' answers it")
        }
    }

    @Test("a type parameter hidden in a declared type refuses at the build")
    func aParameterInADeclaredTypeRefusesAtTheBuild() async throws {
        // Given. A declared type has no call to fill a parameter, and a bound
        // hidden behind the name would otherwise escape every judgment
        let sut = try Module(
            types: ["Weird": .parameter(name: "T", bounds: ["Sortable"])],
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
                    parameters: [.parameter(name: "T", bounds: ["Scalar"])]
                ))
            ],
            contracts: Self.markers("Scalar"),
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
                                        Parameter(name: "it", type: .named("Nope"))
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
            error is BuildError && "\(error)".contains("names type 'Nope', which no module in this link declares")
        }
    }

    @Test("a bounded reading fed to the bound it carries passes")
    func aBoundedReadingFitsItsOwnBound() async throws {
        // Given. Inside a generic body the argument reads as the enclosing
        // parameter, and its bound is what the callee asks
        let sut = try Module(
            procedures: [
                "smallest": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "left", type: .parameter(name: "T", bounds: ["Standard.Comparable"])),
                            Parameter(name: "right", type: .parameter(name: "T", bounds: ["Standard.Comparable"]))
                        ],
                        returns: .bool
                    ),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Comparable.lessThan",
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

    @Test("sorting what does not answer Comparable refuses at the build")
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
            error is BuildError && "\(error)".contains("no document in this link says 'Bool' answers it")
        }
    }

    @Test("min handed null first is held to the parameter it declares first")
    func minHandedNullIsHeldToItsFirstParameter() async throws {
        // Given. The first argument is a reference that reads null, and no
        // document claims `Standard.Comparable` for `Null`, so the boundary
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
            "\(error)".contains("input 'lhs': expected some T: Standard.Comparable, and 'Null' does not answer every procedure 'Standard.Comparable' asks")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Contracts asking no procedures, so what answers one is what the
    // claims say and nothing else.
    private static func markers(_ names: Name...) -> [Name: [Name: Signature]] {
        Dictionary(uniqueKeysWithValues: names.map { name in (name, [Name: Signature]()) })
    }
}

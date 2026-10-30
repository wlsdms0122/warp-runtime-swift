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

// A bounded `some T` takes only what conforms to every contract it is bounded by.
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
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Comparable.lessThan",
                            arguments: [.literal(.bool(true)), .literal(.bool(false))]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'Bool' conforms to")
        }
    }

    @Test("arithmetic on two strings refuses at the build")
    func arithmeticOnTwoStringsRefusesAtTheBuild() async throws {
        // Given. The two sides agree, so the one type parameter reads one
        // thing. Agreement is not conformance: no claim puts strings under
        // `Numeric`.
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Numeric.plus",
                            arguments: [.literal(.string("a")), .literal(.string("b"))]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'String' conforms to")
        }
    }

    @Test("a value read as any stands where a contract call asks only through a cast")
    func aValueReadAsAnyStandsAtAContractCallOnlyThroughACast() async throws {
        // Given. The parameter is declared `Any`, so the build knows nothing
        // the contract could be asked of
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "left", type: .any)],
                        returns: .bool
                    ),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Comparable.lessThan",
                            arguments: [reference("left"), .literal(.int(1))]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'Self' is read as Any, which does not satisfy every procedure 'Standard.Comparable' asks")
        }
    }

    @Test("a module declares a contract of its own and the bound holds")
    func aModuleDeclaresAContractOfItsOwn() async throws {
        // Given. What conforms to the contract is what the claims say, so a
        // signature writes the name and the same judgement Standard's
        // procedures get is this one's
        let sut = try Module(
            contracts: Self.markers("Scalar"),
            claims: ["Int": ["Scalar"], "String": ["Scalar"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T"))],
                        returns: .parameter(name: "T"),
                        bounds: ["T": ["Scalar"]]
                    ),
                    body: [returning(reference("value"))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [returning(.call(Call(selector: "keep", arguments: [.literal(.int(7))])))]
                )
            ]
        )

        // When
        let returned = try await run(sut)

        // Then
        #expect(returned == .int(7))
    }

    @Test("a reading whose type conforms to no declared contract refuses at the build")
    func aDeclaredContractRefusesAtItsOwnBound() async throws {
        // Given
        let sut = try Module(
            contracts: Self.markers("Scalar"),
            claims: ["Int": ["Scalar"], "String": ["Scalar"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .parameter(name: "T"))],
                        returns: .parameter(name: "T"),
                        bounds: ["T": ["Scalar"]]
                    ),
                    body: [returning(reference("value"))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [returning(.call(Call(selector: "keep", arguments: [.literal(.double(1.5))])))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'Double' conforms to")
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
                        parameters: [Parameter(name: "value", type: .parameter(name: "T"))],
                        returns: .parameter(name: "T"),
                        bounds: ["T": ["Sortable"]]
                    ),
                    body: [returning(reference("value"))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [returning(.literal(.int(1)))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("by 'Sortable', which no module in this link declares")
        }
    }

    @Test("a composition inside a slot is held to its bounds where the call is written")
    func aNestedCompositionIsJudgedAtTheBuild() async throws {
        // Given. Int conforms to `A`, String conforms to `A` and `B`, and the
        // slot takes a list of what conforms to both
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
                        body: [returning(.literal(.int(1)))]
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [returning(.call(Call(selector: "keep", arguments: [.literal(.array([element]))])))]
                    )
                ]
            )
        }

        // When / Then
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which holds Array<Int> where Array<A & B> is declared")
        }
    }

    @Test("a composition a declaration promises is held to its bounds")
    func aPromisedCompositionIsJudgedAtTheBuild() async throws {
        // Given. Int conforms to `A`, String conforms to `A` and `B`, and the
        // declaration promises what conforms to both while returning an integer
        let sut = try Module(
            contracts: Self.markers("A", "B"),
            claims: ["Int": ["A"], "String": ["A", "B"]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .composition(["A", "B"])),
                    body: [returning(.literal(.int(1)))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("returns Int, and no claim within reach says 'Int' conforms to 'B'")
        }
    }

    @Test("a name declared as a composition holds only what conforms to every bound")
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
                        ),
                        returning(.literal(.int(1)))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("is given Int, and no claim within reach says 'Int' conforms to 'B'")
        }
    }

    @Test("a type parameter a promise names is satisfied by that parameter alone")
    func aPromisedParameterIsSatisfiedByItself() async throws {
        // Given
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                        returns: .array(.parameter(name: "T"))
                    ),
                    body: [returning(.array([.literal(.int(1)), .literal(.string("x"))]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("and its declaration promises")
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
                    body: [returning(.literal(.int(1)))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [returning(.call(Call(selector: "App.tell", arguments: [.literal(.null)])))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("with it, which holds Null, and no claim within reach says 'Null' conforms to 'App.Describable'")
        }
    }

    @Test("a contract named in a contract's own signature holds the witness to it")
    func aContractInItsOwnSignatureIsJudged() async throws {
        // Given. `describe` promises what conforms to the contract, and the
        // witness returns an integer
        let sut = try Module(
            types: ["Bank.Card": .struct(["last": .string])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .array(.named("App.Describable")))]],
            claims: ["Bank.Card": ["App.Describable"]],
            members: ["Bank.Card": ["describe"]],
            procedures: [
                "Bank.Card.describe": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("Bank.Card"))], returns: .array(.int)),
                    body: [returning(.array([.literal(.int(1))]))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.named("App.Describable")), failing: .these(["cast_refused"])),
                    body: [
                        Statement(
                            binding: .constant("card"),
                            expression: .cast(.struct(["last": .literal(.string("x"))]), as: .named("Bank.Card"), optional: false)
                        ),
                        returning(.call(Call(selector: "App.Describable.describe", arguments: [reference("card")])))
                    ]
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

    @Test("a claim that does not hold refuses at itself, though another claim's member satisfies its requirement through it")
    func aClaimThatDoesNotHoldRefusesAtItself() async throws {
        // Given. `Box` conforms to `Printable` by showing a `Card`, `Card`
        // claims `Describable` and satisfies nothing it asks
        let sut = try Module(
            types: ["App.Box": .struct(["n": .int]), "Bank.Card": .struct(["last": .string])],
            contracts: [
                "App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)],
                "App.Printable": ["show": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .named("App.Describable"))]
            ],
            claims: ["Bank.Card": ["App.Describable"], "App.Box": ["App.Printable"]],
            members: ["App.Box": ["show"]],
            procedures: [
                "App.Box.show": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .named("App.Box"))], returns: .named("Bank.Card")),
                    body: [returning(.struct(["last": .literal(.string("x"))]))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string, failing: .these(["cast_refused"])),
                    body: [
                        Statement(
                            binding: .constant("box"),
                            expression: .cast(.struct(["n": .literal(.int(1))]), as: .named("App.Box"), optional: false)
                        ),
                        Statement(
                            binding: .constant("shown"),
                            expression: .call(Call(selector: "App.Printable.show", arguments: [reference("box")]))
                        ),
                        returning(.call(Call(selector: "App.Describable.describe", arguments: [reference("shown")])))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("types.Bank.Card.satisfies")
                && "\(error)".contains("nothing it stands on gives 'Bank.Card' the member 'describe'")
        }
    }

    @Test("null fills an Optional of a composition whole")
    func nullFillsAnOptionalComposition() async throws {
        // Given
        let sut = try Module(
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            procedures: [
                "App.tell": Procedure(
                    signature: Signature(parameters: [Parameter(name: "it", type: .optional(.named("App.Describable")))], returns: .int),
                    body: [returning(.literal(.int(1)))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [returning(.call(Call(selector: "App.tell", arguments: [.literal(.null)])))]
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
            types: ["App.Pick": .alias(.procedure(ProcedureType(parameters: [.int], returns: .int, failing: .anything)))],
            contracts: Self.markers("App.Marked"),
            claims: ["Int": ["App.Marked"]],
            procedures: [
                "App.take": Procedure(
                    signature: Signature(parameters: [Parameter(name: "p", type: .named("App.Pick"))], returns: .int),
                    body: [returning(.literal(.int(1)))]
                ),
                "App.hand": Procedure(
                    signature: Signature(parameters: [Parameter(name: "x", type: .named("App.Marked"))], returns: .int),
                    body: [returning(.call(Call(selector: "App.take", arguments: [reference("x")])))]
                ),
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [returning(.call(Call(selector: "App.hand", arguments: [.literal(.int(1))])))])
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which holds App.Marked where (Int) throws -> Int is declared")
        }
    }

    @Test("a parameter bounded by two contracts takes only what conforms to both")
    func twoBoundsOnOneParameterBothHold() async throws {
        // Given. Int conforms to `A`, String conforms to `A` and `B`, and `T`
        // is bounded by both
        func module(handing argument: Value) throws -> Module {
            try Module(
                contracts: Self.markers("A", "B"),
                claims: ["Int": ["A"], "String": ["A", "B"]],
                procedures: [
                    "keep": Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "left", type: .parameter(name: "T"))],
                            returns: .int,
                            bounds: ["T": ["A", "B"]]
                        ),
                        body: [returning(.literal(.int(1)))]
                    ),
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [returning(.call(Call(selector: "keep", arguments: [.literal(argument)])))]
                    )
                ]
            )
        }

        // When / Then. A string conforms to both; an integer does not conform
        // to `B`
        _ = try await builder.build([try module(handing: .string("x"))] + Module.standard)

        await #expect {
            try await builder.build([try module(handing: .int(1))] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'Int' conforms to")
        }
    }

    @Test("every slot naming a bounded parameter is held to its bound")
    func everySlotNamingABoundedParameterIsHeld() async throws {
        // Given. `some T` in two slots is one parameter bounded once, so the
        // bound judges both readings
        let sut = try Module(
            contracts: Self.markers("Scalar"),
            claims: ["Int": ["Scalar"], "String": ["Scalar"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "left", type: .parameter(name: "T")),
                            Parameter(name: "right", type: .parameter(name: "T"))
                        ],
                        bounds: ["T": ["Scalar"]]
                    ),
                    body: []
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [returning(.call(Call(selector: "keep", arguments: [.literal(.double(1.0)), .literal(.double(2.0))])))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'Double' conforms to")
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
                            Parameter(name: "left", type: .parameter(name: "T")),
                            Parameter(name: "right", type: .parameter(name: "T"))
                        ],
                        returns: .bool,
                        bounds: ["T": ["Standard.Comparable"]]
                    ),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Comparable.lessThan",
                            arguments: [reference("left"), reference("right")]
                        )))
                    ]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .bool),
                    body: [returning(.call(Call(selector: "smallest", arguments: [.literal(.int(1)), .literal(.int(2))])))]
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard)
        }
    }

    @Test("sorting what does not conform to Comparable refuses at the build")
    func sortingTheUnorderableRefuses() async throws {
        // Given. `sorted` is bounded by `Standard.Comparable`, and
        // booleans are a reading the build can see
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        returning(.call(Call(
                            selector: "Standard.Collection.sorted",
                            arguments: [.literal(.array([.bool(true), .bool(false)]))]
                        )))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no claim within reach says 'Bool' conforms to")
        }
    }

    @Test("min handed a reading of any first refuses at the build")
    func minHandedAReadingOfAnyRefuses() async throws {
        // Given. The first argument is a reference read as `Any`, which stands
        // where a bound is asked only through a cast
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "absent", type: .any)],
                        returns: .any
                    ),
                    body: [returning(.call(Call(selector: "Standard.Math.min", arguments: [reference("absent"), .literal(.int(1))])))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("'T' is read as Any, which does not satisfy every procedure 'Standard.Comparable' asks")
        }
    }

    @Test("a claim refused for a bounded parameter names the bound", arguments: [
        (
            TypeExpression.array(.parameter(name: "T")),
            TypeExpression.int,
            "takes Array<some T: App.Marked> at 1 where the contract writes String"
        ),
        (
            .parameter(name: "T"),
            .parameter(name: "T"),
            "returns some T: App.Marked where the contract writes Int"
        )
    ] as [(TypeExpression, TypeExpression, String)])
    func aClaimRefusalNamesTheBound(takes: TypeExpression, returns: TypeExpression, refusal: String) async throws {
        // Given. `Bank.Card.keep` satisfies `App.Kept.keep` with a type
        // parameter its signature bounds by `App.Marked`, where the contract
        // writes `String` and returns `Int`
        let sut = try Module(
            types: ["Bank.Card": .struct(["last": .string])],
            contracts: Self.markers("App.Marked").merging([
                "App.Kept": [
                    "keep": Signature(
                        parameters: [Parameter(name: "of", type: .selfType), Parameter(name: "with", type: .string)],
                        returns: .int
                    )
                ]
            ]) { held, _ in held },
            claims: ["Bank.Card": ["App.Kept"], "String": ["App.Marked"]],
            members: ["Bank.Card": ["keep"]],
            procedures: [
                "Bank.Card.keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Card")), Parameter(name: "with", type: takes)],
                        returns: returns,
                        bounds: ["T": ["App.Marked"]]
                    ),
                    body: [returning(returns == .int ? .literal(.int(1)) : reference("with"))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int, failing: .these(["cast_refused"])),
                    body: [
                        Statement(
                            binding: .constant("card"),
                            expression: .cast(.struct(["last": .literal(.string("x"))]), as: .named("Bank.Card"), optional: false)
                        ),
                        returning(.call(Call(selector: "App.Kept.keep", arguments: [reference("card"), .literal(.string("y"))])))
                    ]
                )
            ]
        )

        // When / Then. The call leans on the claim, and the reason names the
        // bound the declaration's signature holds `T` to
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains(refusal)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Contracts asking no procedures, so what conforms to one is what the
    // claims say and nothing else.
    private static func markers(_ names: Name...) -> [Name: [Name: Signature]] {
        Dictionary(uniqueKeysWithValues: names.map { name in (name, [Name: Signature]()) })
    }
}

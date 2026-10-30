//
//  LoweringTests.swift
//  WarpTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// What the build writes into a body: which slot a name gets, which cells a
// closure takes, when a loop puts a round back, and where an argument stands.
@Suite("The build lowers a body into slots and rows")
struct LoweringTests {
    // Returns what the variable it was handed holds.
    private struct EchoEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .inout(.int)) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) throws -> Value {
            try invocation.held(.of)
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a name declared again inside an arm gets its own slot")
    func aShadowingDeclarationHasItsOwnSlot() async throws {
        // Given. The inner `x` is a different name, so the outer one reads as
        // it was after the arm
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [
                        Statement(binding: .constant("x"), expression: .literal(.int(1))),
                        Statement(binding: .variable("inner"), expression: .literal(.int(0))),
                        Statement(expression: .conditional(
                            .literal(.bool(true)),
                            then: [
                                Statement(binding: .constant("x"), expression: .literal(.int(2))),
                                Statement(binding: .assignment([.name("inner")]), expression: .reference([.name("x")]))
                            ],
                            else: nil
                        )),
                        returning(.array([.reference([.name("x")]), .reference([.name("inner")])]))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard case let .body(_, layout) = image[entryName]!.implementation else {
            Issue.record("the entry was not lowered")

            return
        }

        #expect(layout.names == ["x", "inner", "x"])
        #expect(try await Executor().run(image) == .array([.int(1), .int(2)]))
    }

    @Test("a closure's own declaration shadows what it captured")
    func aClosureReadsTheNearestName() async throws {
        // Given. The closure declares `x` over the body's `x`; the nearest
        // declaration is the one read, and the body's stays what it was.
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [
                        Statement(binding: .constant("x"), expression: .literal(.int(1))),
                        Statement(binding: .constant("held", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))), expression: .closure(
                            Procedure(
                                signature: Signature(returns: .int),
                                body: [
                                    Statement(binding: .constant("x"), expression: .literal(.int(2))),
                                    returning(.reference([.name("x")]))
                                ]
                            )
                        )),
                        Statement(binding: .constant("got"), expression: .apply(.reference([.name("held")]), arguments: [])),
                        returning(.array([.reference([.name("x")]), .reference([.name("got")])]))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .array([.int(1), .int(2)]))
    }

    @Test("a closure takes only the cells it reads")
    func aClosureCapturesWhatItReads() async throws {
        // Given. Three names in scope, one read
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .constant("a"), expression: .literal(.int(1))),
                        Statement(binding: .constant("b"), expression: .literal(.int(2))),
                        Statement(binding: .constant("c"), expression: .literal(.int(3))),
                        Statement(
                            binding: .constant("held", declared: .procedure(ProcedureType(returns: .int, failing: .these([])))),
                            expression: .closure(Procedure(signature: Signature(returns: .int), body: [returning(.reference([.name("b")]))]))
                        ),
                        returning(.apply(.reference([.name("held")]), arguments: []))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            case let .closure(row, captures) = body.instructions[3].code,
            case let .body(_, inner) = image.linked[row].implementation
        else {
            Issue.record("the closure was not lowered")

            return
        }

        #expect(captures.count == 1)
        #expect(captures.first.map { outer, _ in outer } == 1)
        #expect(inner.names == ["b"])
    }

    @Test("a constant read at an index the run reads is bound before the first statement")
    func aConstantReadAtARunIndexIsBound() async throws {
        // Given. The fold reads `digits`, and cannot read which entry `key`
        // names, so the body reads the constant the way it reads any name
        let module = try Module(
            constants: [
                "digits": dictionary(["0": .literal(.int(0)), "1": .literal(.int(1))])
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "key", type: .string)], returns: .int),
                    body: [
                        Statement(binding: .constant("found"), expression: .reference([.name("digits"), .indexRef([.name("key")])])),
                        returning(.reference([.name("found")]))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)
        let returned = try await Executor().run(image, entry: "entry", arguments: ["key": .string("1")])

        // Then
        #expect(returned == .int(1))

        guard
            case let .body(body, frame) = image["entry"]!.implementation,
            case let .bind(slot)? = body.instructions.first?.binding,
            case let .literal(value) = body.instructions.first!.code
        else {
            Issue.record("the constant was not bound")

            return
        }

        #expect(frame.names[slot] == "digits")
        #expect(value == .dictionary(["0": .int(0), "1": .int(1)]))
    }

    @Test("arguments stand at their parameter's position")
    func argumentsStandByPosition() async throws {
        // Given. A call writing its arguments in the declaration's order, which
        // is not the order the body reads them in
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [
                        returning(.call(Call(
                            selector: "pair",
                            arguments: [.literal(.int(2)), .literal(.int(1)), .literal(.int(3))]
                        )))
                    ]
                ),
                "pair": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "first", type: .int),
                            Parameter(name: "of", type: .int),
                            Parameter(name: "second", type: .int)
                        ],
                        returns: .array(.int)
                    ),
                    body: [
                        returning(.array([
                            .reference([.name("of")]),
                            .reference([.name("first")]),
                            .reference([.name("second")])
                        ]))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            case let .leave(.procedure(.call(call)?))? = body.instructions.last?.code
        else {
            Issue.record("the call was not lowered")

            return
        }

        #expect(image.linked[call.placed.procedure].slots.map(\.name) == ["first", "of", "second"])
        #expect(call.placed.arguments.map { argument in argument == nil } == [false, false, false])
        #expect(try await Executor().run(image) == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("a body declared const reading a module variable refuses")
    func aConstBodyReadingAVariableRefuses() async throws {
        // Given. The variable's value is the run's, so a body reading it
        // is not const, whatever its declaration says
        let module = try Module(
            variables: ["count": .literal(.int(0))],
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "App.tally": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .int, constness: .const),
                    body: [returning(.reference([.name("count")]))]
                )
            ]
        )

        // When, Then
        await #expect(throws: BuildError.self) {
            try await builder.build([module] + Module.standard)
        }
    }

    @Test("a name is what it names, wherever a variable is handed in place")
    func aHandedVariableReadsThroughNames() async throws {
        // Given. `Count` is a name for `Int`, and a name for a scalar is what
        // it names: there is no representation to disagree about, so a variable
        // holding an int is what an `inout Count` slot declares.
        let sut = try Module(
            types: ["Count": .alias(.int)],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .variable("n"), expression: .literal(.int(1))),
                        returning(.call(Call(selector: "App.bump", arguments: [.reference([.name("n")])])))
                    ]
                ),
                "App.bump": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .inout(.named("Count")))],
                        returns: .named("Count")
                    ),
                    body: [returning(.reference([.name("of")]))]
                )
            ]
        )

        // When / Then
        let image = try await builder.build([sut] + Module.standard)

        #expect(try await Executor().run(image) == .int(1))
    }

    @Test("a name is what it names at whatever depth a type holds one")
    func aHandedVariableReadsNamesAtDepth() async throws {
        // Given. The alias sits inside a procedure's parameter rather than at
        // the top of the slot. A name is what it names wherever it is written,
        // so the walk reaches it there too.
        let sut = try Module(
            types: ["Count": .alias(.int)],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("body"), expression: .closure(
                            Procedure(
                                signature: Signature(
                                    parameters: [Parameter(name: "x", type: .int)],
                                    constness: .const,
                                    isolation: .isolated
                                ),
                                body: []
                            )
                        )),
                        returning(.call(Call(selector: "App.take", arguments: [.reference([.name("body")])])))
                    ]
                ),
                "App.take": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .inout(.procedure(ProcedureType(parameters: [.named("Count")], returns: .null, failing: .these([])),
                                    .const,
                                    .isolated
                                ))
                            )
                        ],
                        returns: .null
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.standard)
        }
    }

    @Test("what is handed in place is held to the type the slot declares")
    func aHandedVariableIsTheSlotsOwnType() async throws {
        // Given. A variable holding an `Other`, handed in place to a slot
        // declaring `Tag`. Two declared structs are two types, so it is
        // refused, and the same fields held as a `Tag` stand. The procedure
        // writes through the caller's box, so what the caller reads back is
        // what the procedure left there.
        func module(holding held: Warp.Expression) throws -> Module {
            try Module(
                types: ["Other": .struct(["a": .int]), "Tag": .struct(["a": .int])],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        signature: Signature(returns: .bool, failing: .these(["cast_refused"])),
                        body: [
                            Statement(binding: .variable("held"), expression: held),
                            returning(.call(Call(
                                selector: "Standard.Logic.equal",
                                arguments: [
                                    .call(Call(selector: "App.tag", arguments: [.reference([.name("held")])])),
                                    .cast(.struct(["a": .literal(.int(1))]), as: .named("Tag"), optional: false)
                                ]
                            )))
                        ]
                    ),
                    "App.tag": Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "of", type: .inout(.named("Tag")))],
                            returns: .named("Tag"),
                            constness: .const
                        ),
                        body: [returning(.reference([.name("of")]))]
                    )
                ]
            )
        }

        // When / Then. The `Other` is refused, and the same fields held as a
        // `Tag` stand
        await #expect {
            try await builder.build(
                [try module(holding: .cast(.struct(["a": .literal(.int(1))]), as: .named("Other"), optional: false))]
                    + Module.standard
            )
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'App.tag' with of, which holds Other where inout Tag is declared")
        }

        let image = try await builder.build(
            [try module(holding: .cast(.struct(["a": .literal(.int(1))]), as: .named("Tag"), optional: false))] + Module.standard
        )

        #expect(try await Executor().run(image) == .bool(true))
    }

    @Test("a constant folding through a procedure its own document writes is refused")
    func aConstantFoldingThroughItsOwnProcedureIsRefused() async throws {
        // Given. `J` folds by calling `App.alpha`, a written procedure; while the
        // constants fold every written body stands as its refusal, so the
        // order is not the text's
        let module = try Module(
            constants: [
                "K": .literal(.int(1)),
                "J": .call(Call(selector: "App.alpha", arguments: [reference("K")]))
            ],
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "App.alpha": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .int, constness: .const),
                    body: [returning(.reference([.name("of")]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([module] + Module.standard)
        } throws: { error in
            "\(error)".contains("a cycle with no start")
        }
    }

    @Test("an effect handed a variable in place reads what it holds")
    func anEffectReadsItsHandedArgument() async throws {
        // Given. The first argument is handed in place, so the effect holds it,
        // and reads what the hold holds now
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.int(5))),
                        returning(.call(Call(selector: "App.echo", arguments: [.reference([.name("held")])])))
                    ]
                ),
                "App.echo": Procedure(
                    signature: Signature(of: EchoEffect.self, returns: .int),
                    implementation: .effect(EchoEffect())
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(try await Executor().run(image) == .int(5))
    }

    @Test("a key a write lands in a dictionary keyed by a contract is held as it was read")
    func aKeyWrittenThroughAPathIsHeld() async throws {
        // Given. `k` is read as `Int`, and `m` is keyed by `Hashable`
        let hashable = LoweredType.composition([TypeSpelling.hashable])
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "k", type: .int)]),
                    body: [
                        Statement(
                            binding: .variable("m", declared: .dictionary(key: .named(TypeSpelling.hashable), value: .int)),
                            expression: .dictionary([])
                        ),
                        Statement(binding: .assignment([.name("m"), .indexRef([.name("k")])]), expression: .literal(.int(1)))
                    ]
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            case let .assign(address)? = body.instructions[1].binding,
            case let .at(_, _, coercion)? = address.steps.first
        else {
            Issue.record("the write was not lowered through its key")

            return
        }

        #expect(coercion == .held(.int, in: hashable))
    }

    @Test("a reading that may hold a none is made its Optional's some, and no other is")
    func aReadingThatMayHoldANoneIsWrapped() async throws {
        // Given. `App.f` returns its `some T` as `some T?`, which `T` filled
        // with an Optional makes a none, and `App.g` returns an `Int` as `Int?`
        let module = try Module(
            procedures: [
                "App.f": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                        returns: .optional(.parameter(name: "T"))
                    ),
                    body: [returning(.reference([.name("x")]))]
                ),
                "App.g": Procedure(
                    signature: Signature(parameters: [Parameter(name: "x", type: .int)], returns: .optional(.int)),
                    body: [returning(.reference([.name("x")]))]
                ),
                entryName: Procedure(access: .public, signature: Signature(), body: [])
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(generic, _) = try #require(image["App.f"]).implementation,
            case let .body(plain, _) = try #require(image["App.g"]).implementation,
            case let .leave(.procedure(wrapped?)) = generic.instructions.first?.code,
            case let .leave(.procedure(asItCame?)) = plain.instructions.first?.code
        else {
            Issue.record("the returns were not lowered as leaves")

            return
        }

        guard case .coerced(.local, .wrapped(nil, steps: [])) = wrapped else {
            Issue.record("the generic return is not made its Optional's some")

            return
        }

        guard case .local = asItCame else {
            Issue.record("the return of an Int is not handed on as it came")

            return
        }
    }

    @Test("a list whose elements may hold a none is walked to them where a list of their Optional is asked")
    func aListWhoseElementsMayHoldANoneIsWalked() async throws {
        // Given. `App.f` returns its list of `some T` as a list of `some T?`
        let module = try Module(
            procedures: [
                "App.f": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "xs", type: .array(.parameter(name: "T")))],
                        returns: .array(.optional(.parameter(name: "T")))
                    ),
                    body: [returning(.reference([.name("xs")]))]
                ),
                entryName: Procedure(access: .public, signature: Signature(), body: [])
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(sut, _) = try #require(image["App.f"]).implementation,
            case let .leave(.procedure(walked?)) = sut.instructions.first?.code
        else {
            Issue.record("the return was not lowered as a leave")

            return
        }

        guard case .coerced(.local, .wrapped(nil, steps: [.element])) = walked else {
            Issue.record("the list is not walked to its elements")

            return
        }
    }

    // MARK: - Public
    // MARK: - Private
}

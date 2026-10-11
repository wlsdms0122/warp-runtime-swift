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
    // Answers what the variable it was handed holds.
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
    @Test("a name declared again inside a block gets its own slot")
    func aShadowingDeclarationHasItsOwnSlot() async throws {
        // Given. The inner `x` is a different name, so the outer one reads as
        // it was after the block
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("x"), expression: .literal(.int(1))),
                        Statement(binding: .constant("inner"), expression: .block(
                            Block(
                                body: [Statement(binding: .constant("x"), expression: .literal(.int(2)))],
                                result: .reference([.key("x")])
                            )
                        ))
                    ],
                    result: .array([.reference([.key("x")]), .reference([.key("inner")])])
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

        #expect(layout.names == ["x", "x", "inner"])
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
                    body: [
                        Statement(binding: .constant("x"), expression: .literal(.int(1))),
                        Statement(binding: .constant("held"), expression: .closure(
                            Procedure(
                                body: [Statement(binding: .constant("x"), expression: .literal(.int(2)))],
                                result: .reference([.key("x")])
                            )
                        )),
                        Statement(binding: .constant("got"), expression: .apply(.reference([.key("held")]), arguments: []))
                    ],
                    result: .array([.reference([.key("x")]), .reference([.key("got")])])
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
                    body: [
                        Statement(binding: .constant("a"), expression: .literal(.int(1))),
                        Statement(binding: .constant("b"), expression: .literal(.int(2))),
                        Statement(binding: .constant("c"), expression: .literal(.int(3))),
                        Statement(binding: .constant("held"), expression: .closure(
                            Procedure(body: [], result: .reference([.key("b")]))
                        ))
                    ],
                    result: .apply(.reference([.key("held")]), arguments: [])
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
                "digits": .cast(
                    .record(["0": .literal(.int(0)), "1": .literal(.int(1))]),
                    as: .dictionary(.int),
                    optional: false
                )
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "key", type: .string)]),
                    body: [Statement(binding: .constant("found"), expression: .reference([.key("digits"), .indexRef([.key("key")])]))],
                    result: .reference([.key("found")])
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)
        let answer = try await Executor().run(image, entry: "entry", arguments: ["key": .string("1")])

        // Then
        #expect(answer == .int(1))

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

    @Test("a loop keeps its round's slots only where its result reads them")
    func aLoopKeepsOnlyWhereTheResultCouldTell() async throws {
        // Given. One loop whose result reads a body name; another whose result
        // reads nothing the body bound
        func loop(_ round: Name, _ body: Body, result: Warp.Expression?) -> Warp.Expression {
            .loop(
                while: .call(Call(
                    selector: "Standard.Comparable.lessThan",
                    arguments: [.reference([.key(round), .key("index")]), .literal(.int(1))]
                )),
                body: Block(body: body, result: result)
            )
        }

        let continuing = Statement(expression: .conditional(
            .literal(.bool(false)),
            then: [Statement(expression: .leave(Leave(reach: .round)))],
            else: nil
        ))
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("told"), expression: loop(
                            "told",
                            [Statement(binding: .constant("seen"), expression: .literal(.int(1))), continuing],
                            result: .reference([.key("seen")])
                        )),
                        Statement(binding: .constant("nested"), expression: loop(
                            "nested",
                            [Statement(binding: .constant("seen"), expression: .literal(.int(1))), continuing],
                            result: .reference([.key("nested"), .key("index")])
                        ))
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            case let .loop(_, _, _, told) = body.instructions[0].code,
            case let .loop(_, _, _, nested) = body.instructions[1].code
        else {
            Issue.record("the loops were not lowered")

            return
        }

        #expect(told != nil)
        #expect(nested == nil)
    }

    @Test("arguments stand at their parameter's position")
    func argumentsStandByPosition() async throws {
        // Given. A call writing its arguments in the declaration's order, which
        // is not the order the body reads them in
        let module = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "pair",
                        arguments: [.literal(.int(2)), .literal(.int(1)), .literal(.int(3))]
                    ))
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
                    body: [],
                    result: .array([
                        .reference([.key("of")]),
                        .reference([.key("first")]),
                        .reference([.key("second")])
                    ])
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        guard
            case let .body(body, _) = image[entryName]!.implementation,
            case let .call(call)? = body.result
        else {
            Issue.record("the call was not lowered")

            return
        }

        #expect(image.linked[call.procedure].slots.map(\.name) == ["first", "of", "second"])
        #expect(call.arguments.map { argument in argument == nil } == [false, false, false])
        #expect(try await Executor().run(image) == .array([.int(1), .int(2), .int(3)]))
    }

    @Test("a body reading a module variable does not answer without running")
    func aBodyReadingAVariableIsNotConst() async throws {
        // Given. The variable's value is the run's, so folding the procedure at the
        // build would fix a value nothing at the run could change
        let module = try Module(
            variables: ["count": .literal(.int(0))],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
                "App.tally": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .int),
                    body: [],
                    result: .reference([.key("count")])
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        let tally = try #require(image["App.tally"])

        #expect(tally.constness != .const)
    }

    @Test("a name is what it names, wherever a variable is handed in place")
    func aHandedVariableReadsThroughNames() async throws {
        // Given. `Count` is a name for `Int`, and a name for a scalar is what
        // it names: there is no representation to disagree about, so a variable
        // holding an int is what an `inout Count` slot declares.
        let sut = try Module(
            types: ["Count": .int],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [Statement(binding: .variable("n"), expression: .literal(.int(1)))],
                    result: .call(Call(selector: "App.bump", arguments: [.reference([.key("n")])]))
                ),
                "App.bump": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .inout(.named("Count")))],
                        returns: .named("Count")
                    ),
                    body: [],
                    result: .reference([.key("of")])
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
            types: ["Count": .int],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("body"), expression: .closure(
                            Procedure(
                                signature: Signature(parameters: [Parameter(name: "x", type: .int)]),
                                body: [],
                                result: .literal(.null)
                            )
                        ))
                    ],
                    result: .call(Call(selector: "App.take", arguments: [.reference([.key("body")])]))
                ),
                "App.take": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .inout(.procedure(ProcedureType(parameters: [.named("Count")], returns: .null),
                                    .const,
                                    .isolated
                                ))
                            )
                        ],
                        returns: .null
                    ),
                    body: [],
                    result: .literal(.null)
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
        // Given. A variable holding an unnamed record, handed in place to a
        // slot declaring `Tag`. A nameless record is no value of a declared
        // record, so it is refused, and the same record held as a `Tag`
        // stands. The procedure writes through the caller's box, so what the
        // caller reads back is what the procedure left there.
        func module(holding held: Warp.Expression) throws -> Module {
            try Module(
                types: ["Tag": .record(["a": .int])],
                procedures: [
                    entryName: Procedure(
                        access: .public,
                        body: [Statement(binding: .variable("held"), expression: held)],
                        result: .call(Call(
                            selector: "Standard.Logic.equal",
                            arguments: [
                                .call(Call(selector: "App.tag", arguments: [.reference([.key("held")])])),
                                .cast(.record(["a": .literal(.int(1))]), as: .named("Tag"), optional: false)
                            ]
                        ))
                    ),
                    "App.tag": Procedure(
                        signature: Signature(
                            parameters: [Parameter(name: "of", type: .inout(.named("Tag")))],
                            returns: .named("Tag")
                        ),
                        body: [],
                        result: .reference([.key("of")])
                    )
                ]
            )
        }

        // When / Then. The unnamed record is refused, and the same record held
        // as a `Tag` stands
        await #expect {
            try await builder.build([try module(holding: .record(["a": .literal(.int(1))]))] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sending 'App.tag' with of, which holds { a: Int } where inout Tag is declared")
        }

        let image = try await builder.build(
            [try module(holding: .cast(.record(["a": .literal(.int(1))]), as: .named("Tag"), optional: false))] + Module.standard
        )

        #expect(try await Executor().run(image) == .bool(true))
    }

    @Test("a constant folding through a procedure its own document writes is refused")
    func aConstantFoldingThroughItsOwnProcedureIsRefused() async throws {
        // Given. `J` settles by calling `App.alpha`, a written procedure; while the
        // constants settle every written body stands as its refusal, so the
        // order is not the text's
        let module = try Module(
            constants: [
                "K": .literal(.int(1)),
                "J": .call(Call(selector: "App.alpha", arguments: [reference("K")]))
            ],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
                "App.alpha": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .int),
                    body: [],
                    result: .reference([.key("of")])
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
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.int(5)))
                    ],
                    result: .call(Call(selector: "App.echo", arguments: [.reference([.key("held")])]))
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

    // MARK: - Public
    // MARK: - Private
}

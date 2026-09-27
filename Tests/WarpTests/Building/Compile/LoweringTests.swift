//
//  LoweringTests.swift
//  WarpTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp

// What the build writes into a body: which slot a name gets, which cells a
// closure takes, when a loop puts a round back, and where an argument stands.
@Suite("The build lowers a body into slots and rows")
struct LoweringTests {
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
                "entry": Procedure(
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
        // declaration is the one read, and the body's stays what it was. A
        // module's name may not be declared over, so the order between a
        // captured name and a module variable is never observed.
        let module = try Module(
            procedures: [
                "entry": Procedure(
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
                "entry": Procedure(
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

    @Test("a constant read at an index the run settles is bound before the first statement")
    func aConstantReadAtARunIndexIsBound() async throws {
        // Given. The fold settles `digits`, and cannot settle which entry `key`
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
                "entry": Procedure(
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
            case let .bind(slot, settling)? = body.instructions.first?.binding,
            case let .literal(value) = body.instructions.first!.code
        else {
            Issue.record("the constant was not bound")

            return
        }

        #expect(frame.names[slot] == "digits")
        #expect(settling == nil)
        #expect(value == .dictionary(["0": .int(0), "1": .int(1)]))
    }

    @Test("a loop keeps its round's slots only where its result reads them")
    func aLoopKeepsOnlyWhereTheResultCouldTell() async throws {
        // Given. One loop whose result reads a body name; another whose result
        // reads nothing the body bound
        func loop(_ body: Body, result: Warp.Expression?) -> Warp.Expression {
            .loop(
                while: .call(Call(
                    selector: "std.math.lessThan",
                    arguments: [.reference([.key("round"), .key("index")]), .literal(.int(1))]
                )),
                body: Block(body: body, result: result),
                round: "round"
            )
        }

        let continuing = Statement(expression: .conditional(
            .literal(.bool(false)),
            then: [Statement(expression: .leave(Leave(reach: .round)))],
            else: nil
        ))
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .constant("told"), expression: loop(
                            [Statement(binding: .constant("seen"), expression: .literal(.int(1))), continuing],
                            result: .reference([.key("seen")])
                        )),
                        Statement(binding: .constant("nested"), expression: loop(
                            [Statement(binding: .constant("seen"), expression: .literal(.int(1))), continuing],
                            result: .reference([.key("round"), .key("index")])
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
                "entry": Procedure(
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
        // link would fix a value nothing at the run could change
        let module = try Module(
            variables: ["count": .literal(.int(0))],
            procedures: [
                "entry": Procedure(access: .public, body: [], result: .literal(.null)),
                "app.tally": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .int)], returns: .int),
                    body: [],
                    result: .reference([.key("count")])
                )
            ]
        )

        // When
        let image = try await builder.build([module] + Module.standard)

        // Then
        #expect(image["app.tally"]?.constness != .const)
    }

    @Test("a name is what it names, wherever a variable is handed in place")
    func aHandedVariableReadsThroughNames() async throws {
        // Given. `Count` is a name for `int`, and a name for a scalar is what
        // it names: there is no representation to disagree about, so a variable
        // holding an int is what an `inout Count` slot declares.
        let sut = try Module(
            types: ["Count": .int],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [Statement(binding: .variable("n"), expression: .literal(.int(1)))],
                    result: .call(Call(selector: "app.bump", arguments: [.reference([.key("n")])]))
                ),
                "app.bump": Procedure(
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
                "entry": Procedure(
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
                    result: .call(Call(selector: "app.take", arguments: [.reference([.key("body")])]))
                ),
                "app.take": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .inout(.procedure(ProcedureType(parameters: [.named("Count")]),
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

    @Test("what is handed in place is the type the slot declares, and not one that fits it")
    func aHandedVariableIsTheSlotsOwnType() async throws {
        // Given. A variable holding an unnamed record, handed to a slot
        // declaring `Tag`. By value the boundary would settle it and the procedure
        // would answer it named; in place there is nothing to settle into. The
        // procedure writes through the caller's box, so what the caller reads back
        // is whatever the procedure left there.
        func module(holding held: Warp.Expression) async throws -> Module {
            try Module(
                types: ["Tag": .record(["a": .int])],
                procedures: [
                    "entry": Procedure(
                        access: .public,
                        body: [Statement(binding: .variable("held"), expression: held)],
                        result: .call(Call(
                            selector: "std.logic.equal",
                            arguments: [
                                .call(Call(selector: "app.tag", arguments: [.reference([.key("held")])])),
                                .literal(.record(Record(name: "Tag", ["a": .int(1)])))
                            ]
                        ))
                    ),
                    "app.tag": Procedure(
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
        await #expect(throws: BuildError.self) {
            try await builder.build([try module(holding: .record(["a": .literal(.int(1))]))] + Module.standard)
        }

        let image = try await builder.build(
            [try module(holding: .cast(.record(["a": .literal(.int(1))]), as: .named("Tag"), optional: false))] + Module.standard
        )

        #expect(try await Executor().run(image) == .bool(true))
    }

    @Test("a constant folding through a written procedure is refused whichever is declared first")
    func aConstantFoldingThroughAProcedureIsRefusedInAnyOrder() async throws {
        // Given. `J` settles by calling `app.alpha`, a written procedure; while the
        // constants settle every written body stands as its refusal, so the
        // order is not the text's
        let module = try Module(
            constants: [
                "K": .literal(.int(1)),
                "J": .call(Call(selector: "app.alpha", arguments: [reference("K")]))
            ],
            procedures: [
                "entry": Procedure(access: .public, body: [], result: .literal(.null)),
                "app.alpha": Procedure(
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
            "\(error)".contains("a circle with no start")
        }
    }

    @Test("an effect handed a variable in place reads what it holds")
    func anEffectReadsItsHandedArgument() async throws {
        // Given. The first argument is handed in place, so the effect holds it,
        // and reads what the hold holds now
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("held"), expression: .literal(.int(5)))
                    ],
                    result: .call(Call(selector: "app.echo", arguments: [.reference([.key("held")])]))
                ),
                "app.echo": Procedure(
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

// Answers what the variable it was handed holds.
private struct EchoEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case of

        var declared: Parameter { Parameter(name: "of", type: .inout(.int)) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        try invocation.held(.of)
    }

    // MARK: - Private
}

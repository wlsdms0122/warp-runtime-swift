//
//  LoweringTests.swift
//  WarpTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp

// What the link writes into a body: which slot a name gets, which cells a
// closure takes, when a loop puts a round back, and where an argument stands.
@Suite("The link lowers a body into slots and rows")
struct LoweringTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a name declared again inside a block gets its own slot")
    func aShadowingDeclarationHasItsOwnSlot() async throws {
        // Given — the inner `x` is a different name, so the outer one reads
        // as it was after the block
        let module = try Module(
            procedures: [
                "entry": Procedure(
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
        let image = try linker.link([module] + Module.standard, entry: "entry")

        // Then
        guard case let .body(_, layout) = image.entry.implementation else {
            Issue.record("the entry was not lowered")

            return
        }

        #expect(layout.names == ["x", "x", "inner"])
        #expect(try await Executor().run(image) == .array([.int(1), .int(2)]))
    }

    @Test("a closure's own declaration shadows what it captured")
    func aClosureReadsTheNearestName() async throws {
        // Given — the closure declares `x` over the body's `x`; the nearest
        // declaration is the one read, and the body's stays what it was. A
        // module's name may not be declared over, so the order between a
        // captured name and a module variable is never observed.
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(binding: .constant("x"), expression: .literal(.int(1))),
                        Statement(binding: .constant("held"), expression: .closure(
                            Procedure(
                                body: [Statement(binding: .constant("x"), expression: .literal(.int(2)))],
                                result: .reference([.key("x")])
                            )
                        )),
                        Statement(binding: .constant("got"), expression: .invoke(.reference([.key("held")]), arguments: [:]))
                    ],
                    result: .array([.reference([.key("x")]), .reference([.key("got")])])
                )
            ]
        )

        // When
        let image = try linker.link([module] + Module.standard, entry: "entry")

        // Then
        #expect(try await Executor().run(image) == .array([.int(1), .int(2)]))
    }

    @Test("a closure takes only the cells it reads")
    func aClosureCapturesWhatItReads() throws {
        // Given — three names in scope, one read
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(binding: .constant("a"), expression: .literal(.int(1))),
                        Statement(binding: .constant("b"), expression: .literal(.int(2))),
                        Statement(binding: .constant("c"), expression: .literal(.int(3))),
                        Statement(binding: .constant("held"), expression: .closure(
                            Procedure(body: [], result: .reference([.key("b")]))
                        ))
                    ],
                    result: .invoke(.reference([.key("held")]), arguments: [:])
                )
            ]
        )

        // When
        let image = try linker.link([module] + Module.standard, entry: "entry")

        // Then
        guard
            case let .body(body, _) = image.entry.implementation,
            case let .closure(row, captures) = body.instructions[3].code,
            case let .body(_, inner) = row.implementation
        else {
            Issue.record("the closure was not lowered")

            return
        }

        #expect(captures.count == 1)
        #expect(captures.first.map { outer, _ in outer } == 1)
        #expect(inner.names == ["b"])
    }

    @Test("a loop keeps its round's slots only where its result reads them")
    func aLoopKeepsOnlyWhereTheResultCouldTell() throws {
        // Given — one loop whose result reads a body name; another whose
        // result reads nothing the body bound
        func loop(_ body: [Statement], result: Warp.Expression?) -> Warp.Expression {
            .loop(
                while: .dispatch(Dispatch(
                    receiver: .reference([.key("round"), .key("index")]),
                    selector: "std.math.lessThan",
                    arguments: ["value": .literal(.int(1))]
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
        let image = try linker.link([module] + Module.standard, entry: "entry")

        // Then
        guard
            case let .body(body, _) = image.entry.implementation,
            case let .loop(_, _, _, told) = body.instructions[0].code,
            case let .loop(_, _, _, nested) = body.instructions[1].code
        else {
            Issue.record("the loops were not lowered")

            return
        }

        #expect(told != nil)
        #expect(nested == nil)
    }

    @Test("arguments stand at their parameter's position, and the receiver stands apart")
    func argumentsStandByPosition() async throws {
        // Given — a call writing its arguments in the other order
        let module = try Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.int(1)),
                        selector: "pair",
                        arguments: ["second": .literal(.int(3)), "first": .literal(.int(2))]
                    ))
                ),
                "pair": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .int),
                            "first": Parameter(type: .int),
                            "second": Parameter(type: .int)
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
        let image = try linker.link([module] + Module.standard, entry: "entry")

        // Then
        guard
            case let .body(body, _) = image.entry.implementation,
            case let .send(send)? = body.result
        else {
            Issue.record("the send was not lowered")

            return
        }

        #expect(image.linked[send.procedure].parameters.map(\.name) == ["first", "of", "second"])
        #expect(send.receiver != nil)
        #expect(send.arguments.map { argument in argument == nil } == [false, true, false])
        #expect(try await Executor().run(image) == .array([.int(1), .int(2), .int(3)]))
    }

    // MARK: - Public
    // MARK: - Private
}

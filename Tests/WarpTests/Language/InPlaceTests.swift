//
//  InPlaceTests.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("Writing in place")
struct InPlaceTests {
    @Test("a module variable starts every run at its settled value")
    func moduleVariableStartsFreshEachRun() async throws {
        // Given
        let sut = try Module(
            imports: ["std.math.plus"],
            variables: ["total": .literal(.int(0))],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .assignment([.key("total")]),
                            expression: .dispatch(
                                Dispatch(
                                    receiver: reference("total"),
                                    selector: "std.math.plus",
                                    arguments: ["value": .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: reference("total")
                )
            ]
        )

        let image = try Linker().link([sut] + Module.standard, entry: entryName)

        // When
        let first = try await Executor().run(image)
        let second = try await Executor().run(image)

        // Then
        #expect(first == .int(1))
        #expect(second == .int(1))
    }

    @Test("a module variable is not visible to another document")
    func moduleVariableIsPrivateToItsDocument() throws {
        // Given — the other document writes a name only the first declares
        #expect {
            try Module(
                imports: [],
                procedures: [
                    "other.poke": Procedure(
                        body: [
                            Statement(binding: .assignment([.key("total")]), expression: .literal(.int(1)))
                        ]
                    )
                ]
            )
        } throws: { error in
            "\(error)".contains("not visible")
        }
    }

    @Test("a name is a constant or a variable, and not both")
    func aNameIsBoundOnce() {
        #expect {
            try Module(
                imports: [],
                constants: ["limit": .literal(.int(1))],
                variables: ["limit": .literal(.int(2))],
                procedures: [entryName: Procedure(body: [], result: reference("limit"))]
            )
        } throws: { error in
            "\(error)".contains("one name holds one thing")
        }
    }

    @Test("a path handed in place is written back when the call fails")
    func handedPathIsWrittenBackOnFailure() async throws {
        // Given — the callee writes its box and then aborts; the write lands
        // in the caller's array all the same
        let sut = try Module(
            imports: ["std.control.abort"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .array(.int)),
                    body: [
                        Statement(binding: .variable("xs"), expression: .array([.literal(.int(1)), .literal(.int(2))])),
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(
                                    body: [
                                        Statement(
                                            expression: .dispatch(
                                                Dispatch(
                                                    selector: "poke",
                                                    arguments: ["count": .reference([.key("xs"), .index(1)])]
                                                )
                                            )
                                        )
                                    ]
                                ),
                                rescue: Block(body: [Statement(binding: .constant("seen"), expression: .literal(.int(1)))]),
                                failure: "tried"
                            )
                        )
                    ],
                    result: reference("xs")
                ),
                "poke": Procedure(
                    signature: Signature(parameters: ["count": Parameter(type: .inout(.int))], returns: .never),
                    body: [
                        Statement(binding: .assignment([.key("count")]), expression: .literal(.int(9))),
                        Statement(
                            expression: .dispatch(
                                Dispatch(receiver: .literal(.string("after")), selector: "std.control.abort")
                            )
                        )
                    ]
                )
            ]
        )

        // When
        let answer = try await run(sut)

        // Then
        #expect(answer == .array([.int(1), .int(9)]))
    }

    @Test("a var field holding an inline record is written through")
    func varFieldHoldingAnInlineRecordIsWrittenThrough() async throws {
        // Given — a declared type whose `var` field holds a record nobody
        // declared, so the inner field is nobody's `var` and the path passes
        let sut = try Module(
            imports: [],
            types: ["Outer": .record(["inner": .variable(.record(["a": .int]))])],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("held"),
                            expression: .cast(.record(["inner": .record(["a": .literal(.int(1))])]), as: .named("Outer"), optional: false)
                        ),
                        Statement(binding: .assignment([.key("held"), .key("inner"), .key("a")]), expression: .literal(.int(5)))
                    ],
                    result: reference("held", "inner", "a")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(5))
    }

    @Test("inout is written on a parameter and nowhere else")
    func inoutOutsideAParameterRefuses() throws {
        // Given — a declared type with an inout field
        let sut = try Module(
            imports: [],
            types: ["Box": .record(["held": .inout(.int)])],
            procedures: [entryName: Procedure(body: [], result: .literal(.null))]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("only a parameter is handed a variable in place")
        }
    }

    @Test("var is written on a declared type's field and nowhere else")
    func varOutsideADeclaredFieldRefuses() throws {
        // Given — a parameter typed var
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["count": Parameter(type: .variable(.int))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("only a field of a declared type is written through")
        }
    }

    @Test("a closure a caller assembled claims nothing, and fits only a slot that asks nothing")
    func anAssembledClosureClaimsNothing() throws {
        // Given
        let closure = Closure(procedure: Procedure(body: [], result: .literal(.int(1))), captured: Scope())

        // When / Then
        #expect(throws: ArgumentError.self) {
            try TypeExpression.procedure(nil, .unstated, .isolated)
                .settling(.procedure(closure), at: "piece", in: TypeTable())
        }
        #expect(throws: Never.self) {
            try TypeExpression.procedure(nil)
                .settling(.procedure(closure), at: "piece", in: TypeTable())
        }
    }
}

//
//  InPlaceTests.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

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
        // Given. The other document writes a name only the first declares
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

    @Test("a path handed in place is written as it is made, so a failing call has written")
    func handedPathIsWrittenBeforeFailure() async throws {
        // Given. The callee writes through the path and then aborts; the write
        // is in the caller's array all the same
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
        // Given. A declared type whose `var` field holds a record nobody
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

    @Test("a module variable handed in place is one box, by the parameter and by its name")
    func moduleVariableHandedInPlaceIsOneBox() async throws {
        // Given. A body handed a part of the module variable writes the part,
        // then reads the whole by name
        let sut = try Module(
            imports: [],
            variables: ["items": .array([.literal(.int(1)), .literal(.int(2))])],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .array(.int)),
                    body: [],
                    result: .dispatch(Dispatch(selector: "poke", arguments: ["first": .reference([.key("items"), .index(0)])]))
                ),
                "poke": Procedure(
                    signature: Signature(parameters: ["first": Parameter(type: .inout(.int))], returns: .array(.int)),
                    body: [Statement(binding: .assignment([.key("first")]), expression: .literal(.int(9)))],
                    result: reference("items")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .array([.int(9), .int(2)]))
    }

    @Test("a hold whose box no longer has the part refuses the read")
    func handedPathReadsWhatTheBoxHoldsNow() async throws {
        // Given. The callee is handed the second element, then writes the whole
        // array shorter by name, then reads the parameter
        let sut = try Module(
            imports: [],
            variables: ["items": .array([.literal(.int(1)), .literal(.int(2))])],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .dispatch(Dispatch(selector: "poke", arguments: ["second": .reference([.key("items"), .index(1)])]))
                ),
                "poke": Procedure(
                    signature: Signature(parameters: ["second": Parameter(type: .inout(.int))], returns: .int),
                    body: [Statement(binding: .assignment([.key("items")]), expression: .array([.literal(.int(7))]))],
                    result: reference("second")
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut)
        } throws: { error in
            "\(error)".contains("reads element 1 of an array holding 1")
        }
    }

    @Test("an entry not written yet is handed in place and made by the write")
    func unwrittenEntryIsHandedInPlace() async throws {
        // Given. The callee only writes its parameter, so the entry is never
        // read before it is there
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("table"),
                            expression: .cast(.record([:]), as: .dictionary(.int), optional: false)
                        ),
                        Statement(
                            expression: .dispatch(Dispatch(selector: "fill", arguments: ["slot": reference("table", "k")]))
                        )
                    ],
                    result: reference("table", "k")
                ),
                "fill": Procedure(
                    signature: Signature(parameters: ["slot": Parameter(type: .inout(.int))]),
                    body: [Statement(binding: .assignment([.key("slot")]), expression: .literal(.int(3)))],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(3))
    }

    @Test("a write into an inout parameter has to fit the declared type")
    func writeIntoInoutParameterIsHeldToItsType() throws {
        // Given. The body writes a string into a parameter declared inout int
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .variable("xs"), expression: .array([.literal(.int(1))])),
                        Statement(
                            expression: .dispatch(Dispatch(selector: "poke", arguments: ["first": .reference([.key("xs"), .index(0)])]))
                        )
                    ],
                    result: .literal(.null)
                ),
                "poke": Procedure(
                    signature: Signature(parameters: ["first": Parameter(type: .inout(.int))]),
                    body: [Statement(binding: .assignment([.key("first")]), expression: .literal(.string("text")))],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("first")
        }
    }

    @Test("a path handed in place has to read as the declared type")
    func handedPathIsHeldToTheDeclaredType() throws {
        // Given. An int element is handed to a parameter declared inout string
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(binding: .variable("xs"), expression: .array([.literal(.int(1))])),
                        Statement(
                            expression: .dispatch(Dispatch(selector: "poke", arguments: ["first": .reference([.key("xs"), .index(0)])]))
                        )
                    ],
                    result: .literal(.null)
                ),
                "poke": Procedure(
                    signature: Signature(parameters: ["first": Parameter(type: .inout(.string))]),
                    body: [Statement(binding: .assignment([.key("first")]), expression: .literal(.string("text")))],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect {
            try Linker().link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("first")
        }
    }

    @Test("a part of a box handed in place is handed on like any local's")
    func aHandedBoxIsSplitOnwards() throws {
        // Given. A body handed `all` whole hands `all.items` on to another
        // written body
        let sut = try Module(
            imports: ["other.grow"],
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["all": Parameter(type: .inout(.record(["items": .array(.int)])))]),
                    body: [
                        Statement(
                            expression: .dispatch(Dispatch(selector: "other.grow", arguments: ["list": reference("all", "items")]))
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )
        let other = try Module(
            imports: [],
            procedures: [
                "other.grow": Procedure(
                    signature: Signature(parameters: ["list": Parameter(type: .inout(.array(.int)))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try Linker().link([sut, other] + Module.standard, entry: entryName)
        }
    }

    @Test("inout is written on a parameter and nowhere else")
    func inoutOutsideAParameterRefuses() throws {
        // Given. A declared type with an inout field
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
        // Given. A parameter typed var
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
        // Given. Assembled against the table it is judged against, so what is
        // being asked is the claim and not which link made the row
        let types = TypeTable()
        let closure = Closure.assembled(answering: .int(1), in: types.shapes)

        // When / Then
        #expect(throws: ArgumentError.self) {
            try TypeExpression.procedure(nil, .unstated, .isolated)
                .settling(.procedure(closure), at: "piece", in: types)
        }
        #expect(throws: Never.self) {
            try TypeExpression.procedure(nil)
                .settling(.procedure(closure), at: "piece", in: types)
        }
    }

    @Test("a path write reaches a nameless record and the dictionary it equals the same way")
    func aPathWriteReadsEitherSpelling() throws {
        // Given. The contract says these are one value
        let laid = Value.record(Record(name: nil, ["a": .int(1)]))
        let held = Value.dictionary(["a": .int(1)])
        let path: [PathSegment] = [.key("b", optional: false)]

        // When / Then
        #expect(laid == held)
        #expect(
            try laid.writing(.int(2), at: path, under: "x.b")
                == (try held.writing(.int(2), at: path, under: "x.b"))
        )
    }
}

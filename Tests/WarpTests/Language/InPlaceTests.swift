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
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .assignment([.key("total")]),
                            expression: .call(
                                Call(
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

        let image = try await Builder().build([sut] + Module.standard)

        // When
        let first = try await Executor().run(image)
        let second = try await Executor().run(image)

        // Then
        #expect(first == .int(1))
        #expect(second == .int(1))
    }

    @Test("a module variable settled as a dictionary is written under new names")
    func moduleVariableSettledAsADictionaryTakesNewNames() async throws {
        // Given. An empty dictionary to start with: a dictionary's names are
        // data, so what it reads as is what its entries hold, not which names
        // it holds them under.
        let sut = try Module(
            imports: ["std.collection.keys", "std.collection.setting"],
            variables: ["seen": .literal(.dictionary(Value.Dictionary([:])))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.string)),
                    body: [
                        Statement(
                            binding: .assignment([.key("seen")]),
                            expression: .call(
                                Call(
                                    receiver: reference("seen"),
                                    selector: "std.collection.setting",
                                    arguments: ["key": .literal(.string("a")), "value": .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: .call(Call(receiver: reference("seen"), selector: "std.collection.keys"))
                )
            ]
        )

        // When
        let answer = try await Executor().run(try await Builder().build([sut] + Module.standard))

        // Then
        #expect(answer == .array([.string("a")]))
    }

    @Test("a module variable holds the type it declares, whatever it started as")
    func moduleVariableHoldsItsDeclaredType() async throws {
        // Given. An empty dictionary start under a declared entry type: the
        // start says nothing about what the box will hold, the declaration
        // does, and a write of something else is held to it.
        let sut = try Module(
            variables: ["seen": ModuleVariable(.literal(.dictionary(Value.Dictionary([:]))), declared: .dictionary(.int))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .dictionary(.int)),
                    body: [
                        Statement(binding: .assignment([.key("seen")]), expression: .literal(.string("not a dictionary")))
                    ],
                    result: reference("seen")
                )
            ]
        )

        // When / Then. The write is held to the declared type.
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }
    }

    @Test("a module variable's start is settled into the type it declares")
    func moduleVariableStartIsSettledIntoItsDeclaredType() async throws {
        // Given. A start the declared type does not take.
        let sut = try Module(
            variables: ["total": ModuleVariable(.literal(.string("many")), declared: .int)],
            procedures: [
                entryName: Procedure(access: .public, signature: Signature(returns: .int), body: [], result: reference("total"))
            ]
        )

        // When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build([sut] + Module.standard)
        }
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
                procedures: [entryName: Procedure(access: .public, body: [], result: reference("limit"))]
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
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [
                        Statement(binding: .variable("xs"), expression: .array([.literal(.int(1)), .literal(.int(2))])),
                        Statement(
                            binding: .constant("tried"),
                            expression: .attempt(
                                Block(
                                    body: [
                                        Statement(
                                            expression: .call(
                                                Call(
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
                    signature: Signature(parameters: [Parameter(name: "count", type: .inout(.int))], returns: .never),
                    body: [
                        Statement(binding: .assignment([.key("count")]), expression: .literal(.int(9))),
                        Statement(
                            expression: .call(
                                Call(receiver: .literal(.string("after")), selector: "std.control.abort")
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
                    access: .public,
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
                    access: .public,
                    signature: Signature(returns: .array(.int)),
                    body: [],
                    result: .call(Call(selector: "poke", arguments: ["first": .reference([.key("items"), .index(0)])]))
                ),
                "poke": Procedure(
                    signature: Signature(parameters: [Parameter(name: "first", type: .inout(.int))], returns: .array(.int)),
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
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "poke", arguments: ["second": .reference([.key("items"), .index(1)])]))
                ),
                "poke": Procedure(
                    signature: Signature(parameters: [Parameter(name: "second", type: .inout(.int))], returns: .int),
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
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .variable("table"),
                            expression: .cast(.record([:]), as: .dictionary(.int), optional: false)
                        ),
                        Statement(
                            expression: .call(Call(selector: "fill", arguments: ["slot": reference("table", "k")]))
                        )
                    ],
                    result: reference("table", "k")
                ),
                "fill": Procedure(
                    signature: Signature(parameters: [Parameter(name: "slot", type: .inout(.int))]),
                    body: [Statement(binding: .assignment([.key("slot")]), expression: .literal(.int(3)))],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .int(3))
    }

    @Test("a write into an inout parameter has to fit the declared type")
    func writeIntoInoutParameterIsHeldToItsType() async throws {
        // Given. The body writes a string into a parameter declared inout int
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("xs"), expression: .array([.literal(.int(1))])),
                        Statement(
                            expression: .call(Call(selector: "poke", arguments: ["first": .reference([.key("xs"), .index(0)])]))
                        )
                    ],
                    result: .literal(.null)
                ),
                "poke": Procedure(
                    signature: Signature(parameters: [Parameter(name: "first", type: .inout(.int))]),
                    body: [Statement(binding: .assignment([.key("first")]), expression: .literal(.string("text")))],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("first")
        }
    }

    @Test("a path handed in place has to read as the declared type")
    func handedPathIsHeldToTheDeclaredType() async throws {
        // Given. An int element is handed to a parameter declared inout string
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("xs"), expression: .array([.literal(.int(1))])),
                        Statement(
                            expression: .call(Call(selector: "poke", arguments: ["first": .reference([.key("xs"), .index(0)])]))
                        )
                    ],
                    result: .literal(.null)
                ),
                "poke": Procedure(
                    signature: Signature(parameters: [Parameter(name: "first", type: .inout(.string))]),
                    body: [Statement(binding: .assignment([.key("first")]), expression: .literal(.string("text")))],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("first")
        }
    }

    @Test("a part of a box handed in place is handed on like any local's")
    func aHandedBoxIsSplitOnwards() async throws {
        // Given. A body handed `all` whole hands `all.items` on to another
        // written body
        let sut = try Module(
            imports: ["other.grow"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "all", type: .inout(.record(["items": .array(.int)])))]),
                    body: [
                        Statement(
                            expression: .call(Call(selector: "other.grow", arguments: ["list": reference("all", "items")]))
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
                    signature: Signature(parameters: [Parameter(name: "list", type: .inout(.array(.int)))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect(throws: Never.self) {
            try await Builder().build([sut, other] + Module.standard)
        }
    }

    @Test("inout is written on a parameter and nowhere else")
    func inoutOutsideAParameterRefuses() async throws {
        // Given. A declared type with an inout field
        let sut = try Module(
            imports: [],
            types: ["Box": .record(["held": .inout(.int)])],
            procedures: [entryName: Procedure(access: .public, body: [], result: .literal(.null))]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("only a parameter is handed a variable in place")
        }
    }

    @Test("var is written on a declared type's field and nowhere else")
    func varOutsideADeclaredFieldRefuses() async throws {
        // Given. A parameter typed var
        let sut = try Module(
            imports: [],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "count", type: .variable(.int))]),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            "\(error)".contains("only a field of a declared type is written through")
        }
    }

    @Test("a closure a caller assembled claims nothing, and fits only a slot that asks nothing")
    func anAssembledClosureClaimsNothing() throws {
        // Given. Assembled against the table it is judged against, so what is
        // being asked is the claim and not which link made the row
        let types = TypeTable()
        let closure = Closure.assembled(answering: .int(1), in: types.loweredTypes)

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
        let path: [Projection] = [.key("b")]

        // When / Then
        #expect(laid == held)
        #expect(
            try laid.writing(.int(2), at: path, under: "x.b")
                == (try held.writing(.int(2), at: path, under: "x.b"))
        )
    }
}

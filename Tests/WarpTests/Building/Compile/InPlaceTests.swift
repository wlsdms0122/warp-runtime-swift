//
//  InPlaceTests.swift
//  WarpTests
//
//  Created by JSilver on 9/3/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

@Suite("Writing in place")
struct InPlaceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
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
                                Call(selector: "std.math.plus", arguments: [reference("total"), .literal(.int(1))])
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
                                    selector: "std.collection.setting",
                                    arguments: [reference("seen"), .literal(.string("a")), .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "std.collection.keys", arguments: [reference("seen")]))
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
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("writes 'seen' as string, and it holds dictionary<int>")
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
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("starts as string, and declares int")
        }
    }

    @Test("a document writes only the variables it declares")
    func aDocumentWritesOnlyItsOwnVariables() {
        // Given. One write of `app.total`
        let write = Statement(binding: .assignment([.key("app.total")]), expression: .literal(.int(1)))

        // When / Then. Taken at the load of the document declaring
        // `app.total`, and refused at the load of one that does not, though
        // it imports the name
        #expect(throws: Never.self) {
            try Module(
                variables: ["app.total": .literal(.int(0))],
                procedures: ["app.poke": Procedure(body: [write])]
            )
        }
        #expect {
            try Module(imports: ["app.total"], procedures: ["other.poke": Procedure(body: [write])])
        } throws: { error in
            error is ValidationError && "\(error)".contains("assigns 'app.total', which is not visible here")
        }
    }

    @Test("a name is a constant or a variable, and not both")
    func aNameIsBoundOnce() {
        // When / Then
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
                                                Call(selector: "poke", arguments: [.reference([.key("xs"), .index(1)])])
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
                                Call(selector: "std.control.abort", arguments: [.literal(.string("after"))])
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
                    result: .call(Call(selector: "poke", arguments: [.reference([.key("items"), .index(0)])]))
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
                    result: .call(Call(selector: "poke", arguments: [.reference([.key("items"), .index(1)])]))
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
                            expression: .call(Call(selector: "fill", arguments: [reference("table", "k")]))
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
                            expression: .call(Call(selector: "poke", arguments: [.reference([.key("xs"), .index(0)])]))
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
                            expression: .call(Call(selector: "poke", arguments: [.reference([.key("xs"), .index(0)])]))
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
                            expression: .call(Call(selector: "other.grow", arguments: [reference("all", "items")]))
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

    // MARK: - Public
    // MARK: - Private
}

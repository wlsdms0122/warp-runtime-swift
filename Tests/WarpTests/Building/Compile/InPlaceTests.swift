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
import WarpTestSupport

@Suite("Writing in place")
struct InPlaceTests {
    // Calls the procedure it is handed with one value, the way a procedure the
    // host answers calls what it is handed.
    private struct CallingEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case body

            // MARK: - Property
            var declared: Parameter { Parameter(name: "body", type: .procedure(nil)) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            guard case let .procedure(closure) = invocation[.body] else { return .null }

            return try await invocation.call(closure, handing: [.int(1)])
        }

        // MARK: - Private
    }

    // Declares it is handed a procedure taking its one parameter in place.
    private struct InPlaceCallingEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case body

            // MARK: - Property
            var declared: Parameter {
                Parameter(name: "body", type: .procedure(ProcedureType(parameters: [.inout(.int)])))
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            .null
        }

        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a module variable starts every run at its settled value")
    func moduleVariableStartsFreshEachRun() async throws {
        // Given
        let sut = try Module(
            imports: ["Standard.Numeric.plus"],
            variables: ["total": .literal(.int(0))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(
                            binding: .assignment([.key("total")]),
                            expression: .call(
                                Call(selector: "Standard.Numeric.plus", arguments: [reference("total"), .literal(.int(1))])
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
        // Given. A dictionary of one name to start with: a dictionary's names
        // are data, so what it reads as is what its entries hold, not which
        // names it holds them under.
        let sut = try Module(
            imports: ["Standard.Collection.keys", "Standard.Collection.setting"],
            variables: ["seen": .literal(.dictionary(Value.Dictionary(["x": .int(0)])))],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .array(.string)),
                    body: [
                        Statement(
                            binding: .assignment([.key("seen")]),
                            expression: .call(
                                Call(
                                    selector: "Standard.Collection.setting",
                                    arguments: [reference("seen"), .literal(.string("a")), .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "Standard.Collection.keys", arguments: [reference("seen")]))
                )
            ]
        )

        // When
        let answer = try await Executor().run(try await Builder().build([sut] + Module.standard))

        // Then
        #expect(answer == .array([.string("a"), .string("x")]))
    }

    @Test("a module variable that starts empty and declares nothing is refused")
    func moduleVariableStartedEmptyIsRefused() async throws {
        // Given. A variable that declares nothing holds the type of its start,
        // and an empty dictionary holds no entry, so nothing says what the box
        // will hold
        let sut = try Module(
            variables: ["seen": .literal(.dictionary(Value.Dictionary([:])))],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null))
            ]
        )

        // When / Then
        await #expect {
            try await Builder().build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("which holds nothing, and declares no type")
        }
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
            error is BuildError && "\(error)".contains("writes 'seen' as String, and it holds Dictionary<Int>")
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
            error is BuildError && "\(error)".contains("starts as String, and declares Int")
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
            imports: ["Standard.Control.abort"],
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
                                rescue: Block(body: [Statement(binding: .constant("seen"), expression: .literal(.int(1)))])
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
                                Call(selector: "Standard.Control.abort", arguments: [.literal(.string("after"))])
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
        // Given. The body writes a string into a parameter declared `inout Int`
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
        // Given. An int element is handed to a parameter declared `inout String`
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
            imports: ["Other.grow"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "all", type: .inout(.record(["items": .array(.int)])))]),
                    body: [
                        Statement(
                            expression: .call(Call(selector: "Other.grow", arguments: [reference("all", "items")]))
                        )
                    ],
                    result: .literal(.null)
                )
            ]
        )
        let other = try Module(
            imports: [],
            procedures: [
                "Other.grow": Procedure(
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

    @Test("a call of a value keeps a place where its type takes one in place and reads every other argument")
    func aCallOfAValueLowersWhatItHandsInPlace() async throws {
        // Given. Two variables handed to a value taking the first in place and
        // the second as a value
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("n"), expression: .literal(.int(1))),
                        Statement(binding: .variable("m"), expression: .literal(.int(2))),
                        Statement(
                            binding: .constant("pair"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(
                                        parameters: [
                                            Parameter(name: "first", type: .inout(.int)),
                                            Parameter(name: "second", type: .int)
                                        ]
                                    ),
                                    body: [],
                                    result: .literal(.null)
                                )
                            )
                        ),
                        Statement(expression: .apply(reference("pair"), arguments: [reference("n"), reference("m")]))
                    ],
                    result: .literal(.null)
                )
            ]
        )

        // When
        let image = try await Builder().build([sut] + Module.standard)

        // Then
        let entry = try #require(image[entryName])

        guard
            case let .body(body, _) = entry.implementation,
            case let .apply(_, arguments)? = body.instructions.last?.code
        else {
            Issue.record("the entry's last statement is a call of a value")
            return
        }

        guard case .reference = arguments.first, case .value(.local) = arguments.last else {
            Issue.record("the first argument is a place and the second a read")
            return
        }
    }

    @Test("a procedure the host answers calling a closure that takes a parameter in place is refused before the closure runs")
    func aHostCallOfAClosureTakingInPlaceRefuses() async throws {
        // Given. The closure would answer what it was handed, and a run that
        // reached its body would answer 1
        let calling = try Module(
            procedures: [
                "App.calling": Procedure(
                    signature: Signature(of: CallingEffect.self),
                    implementation: .effect(CallingEffect())
                )
            ]
        )
        let sut = try Module(
            imports: ["App.calling"],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("reading"),
                            expression: .closure(
                                Procedure(
                                    signature: Signature(
                                        parameters: [Parameter(name: "count", type: .inout(.int))],
                                        returns: .int
                                    ),
                                    body: [],
                                    result: reference("count")
                                )
                            )
                        )
                    ],
                    result: .call(Call(selector: "App.calling", arguments: [reference("reading")]))
                )
            ]
        )

        let image = try await Builder().build([sut, calling] + Module.standard)

        // When / Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            error is ExecutionError && "\(error)".contains("takes 'count' in place, and this call hands it a value")
        }
    }

    @Test(
        "a procedure the host answers declaring a parameter that may hold a procedure taking one in place is refused at the build",
        arguments: [
            "plain",
            "nullable",
            "array",
            "dictionary",
            "record field",
            "declared name"
        ]
    )
    func aHostProcedureTakingAnInPlaceProcedureRefuses(wrapped: String) async {
        // Given. The same procedure type, held each way a slot may hold it
        let taking = TypeExpression.procedure(ProcedureType(parameters: [.inout(.int)]))
        let held: [String: TypeExpression] = [
            "plain": taking,
            "nullable": .nullable(taking),
            "array": .array(taking),
            "dictionary": .dictionary(taking),
            "record field": .record(["hook": taking]),
            "declared name": .named("App.Hook")
        ]
        let calling = try? Module(
            types: ["App.Hook": taking],
            procedures: [
                "App.calling": Procedure(
                    signature: Signature(parameters: [Parameter(name: "body", type: held[wrapped])]),
                    implementation: .effect(InPlaceCallingEffect())
                )
            ]
        )

        // When
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build([try #require(calling)] + Module.standard)
        }

        // Then
        #expect(
            refusal?.message.contains(
                "takes 'body', which may hold a procedure taking a parameter in place,"
                    + " and a procedure the host answers calls what it is handed with values"
            ) == true
        )
    }

    @Test("a literal refused where a parameter handed in place holds a list of a type parameter is named part by part")
    func aRefusedLiteralIsNamedPartByPart() async throws {
        // Given. `App.g` writes its own `some T` beside a value read as `Any`, and a record of an empty list beside one of `Any`, into lists it was handed in place
        let generic = TypeExpression.parameter(name: "T")
        let list = try Module(
            procedures: [
                "App.list": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "xs", type: .inout(.array(generic))),
                            Parameter(name: "x", type: generic),
                            Parameter(name: "junk", type: .any)
                        ],
                        returns: .int
                    ),
                    body: [
                        Statement(
                            binding: .assignment([.key("xs")]),
                            expression: .array([.reference([.key("x")]), .reference([.key("junk")])])
                        )
                    ],
                    result: .literal(.int(0))
                )
            ]
        )
        let records = try Module(
            procedures: [
                "App.records": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "ds", type: .inout(.array(.dictionary(.array(generic))))),
                            Parameter(name: "junk", type: .any)
                        ],
                        returns: .int
                    ),
                    body: [
                        Statement(
                            binding: .assignment([.key("ds")]),
                            expression: .array([
                                .record(["k": .array([])]),
                                .record(["k": .array([.reference([.key("junk")])])])
                            ])
                        )
                    ],
                    result: .literal(.int(0))
                )
            ]
        )

        // When
        let listRefusal = await #expect(throws: BuildError.self) {
            try await Builder().build([list] + Module.standard)
        }
        let recordsRefusal = await #expect(throws: BuildError.self) {
            try await Builder().build([records] + Module.standard)
        }

        // Then
        #expect(listRefusal?.message == "writes 'xs' as [some T, Any], and it holds Array<some T>")
        #expect(recordsRefusal?.message == "writes 'ds' as [{ k: [] }, { k: Array<Any> }], and it holds Array<Dictionary<Array<some T>>>")
    }

    // MARK: - Public
    // MARK: - Private
}

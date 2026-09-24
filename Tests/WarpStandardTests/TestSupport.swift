//
//  TestSupport.swift
//  WarpStandardTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
import Warp
import WarpTestSupport
import WarpStandard

// What a test writes to reach a procedure: a program authored as Swift values, run
// with the bundles the procedure lives in. This target writes its own fixtures, in
// the type a vocabulary test takes, so a change to the language's own
// fixtures cannot fail a procedure's test for a reason the procedure had nothing to do
// with.

// MARK: - Writing

// A reference from segment names, written directly: a path is what the
// language has, and the spelling belongs to whatever produced it.
func reference(_ names: Name...) -> Warp.Expression {
    .reference(names.map { name in .key(name) })
}

func literal(_ text: String) -> Warp.Expression {
    .literal(.string(text))
}

// A template as the language holds one: pieces written one after another, each
// value asked how it reads.
func interpolated(_ pieces: Warp.Expression...) -> Warp.Expression {
    .call(Call(selector: "std.text.joined", arguments: [.array(pieces)]))
}

func spelling(_ value: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.text.text", arguments: [value]))
}

func refusing(_ message: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.control.abort", arguments: [message]))
}

// Equality and the connectives are procedures, so a test writing one writes the
// send the notation lowers to.
func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.logic.equal", arguments: [subject, operand]))
}

// A connective leaves its later sides unasked, so each arrives as something
// that has not been answered yet.
func every(_ conditions: Warp.Expression...) -> Warp.Expression {
    .call(
        Call(
            selector: "std.logic.and",
            arguments: [
                .array(
                    conditions.map { condition in
                        .closure(
                            Procedure(
                                implementation: .body(Block(body: [], result: condition)),
                                constness: .const
                            )
                        )
                    }
                )
            ]
        )
    )
}

// MARK: - Running

// The entry name these tests link against. Any name would do, since which
// procedure a run starts from is an argument.
let entryName: Name = "entry"

func run(
    _ modules: [Module],
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
    environment: (any Environment)? = nil
) async throws -> Value {
    let image = try await Builder().build(try modules.map { module in try module.publishing(entry) } + vocabulary)

    return try await Executor(environment: environment).run(image, entry: entry, arguments: arguments)
}

func run(
    _ module: Module,
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
    environment: (any Environment)? = nil
) async throws -> Value {
    try await run(
        [module],
        entry: entry,
        arguments: arguments,
        vocabulary: vocabulary,
        environment: environment
    )
}

func run(
    _ procedure: Procedure,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard
) async throws -> Value {
    try await run(
        [try Module(procedures: others.merging([entryName: procedure.with(access: .public)]) { _, new in new })],
        arguments: arguments,
        vocabulary: vocabulary
    )
}

// What a body answers with, for the tests that care about one value rather
// than a result map.
func answer(
    of body: [Statement],
    result: Warp.Expression,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    signature: Signature = Signature(),
    vocabulary: [Module] = Module.standard
) async throws -> Value? {
    try await run(
        Procedure(signature: signature, body: body, result: result),
        beside: others,
        arguments: arguments,
        vocabulary: vocabulary
    )
}

// MARK: - Vocabulary

// Vocabulary is modules, so a test that needs a procedure beyond the standard ones
// declares one and puts it in the link.
extension Module {
    static let shouting = try! Module(
        procedures: [
            "app.shout": Procedure(
                signature: Signature(of: ShoutEffect.self, returns: .string),
                implementation: .effect(ShoutEffect())
            )
        ]
    )
}

struct ShoutEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case text

        var declared: Parameter { Parameter(name: "text", type: .string) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        .string(invocation.string(.text)?.uppercased() ?? "")
    }

    // MARK: - Private
}


// A test's image runs from the test's entry unless the test names another.
extension Executor {
    func run(_ image: Image, arguments: [Name: Value] = [:]) async throws -> Value {
        try await run(image, entry: entryName, arguments: arguments)
    }
}

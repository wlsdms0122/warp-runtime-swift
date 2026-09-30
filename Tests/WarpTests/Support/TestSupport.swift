//
//  TestSupport.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport
import WarpStandard

// This target imports no notation, on purpose. Every other test in the
// package reaches the language through one, which means it proves two things
// at once and cannot say which one broke. What is written here is the language
// on its own: procedures authored as Swift values, paths written as segments
// rather than parsed from text. The standard vocabulary comes in because a
// program has to call somewhere, and what those procedures answer is tested where
// they live.

// A statement that may fail and does not: a plain cast onto a type the value
// already fits. An `attempt` stands only over a body that can fail, so a test
// showing what a rescue does *not* catch puts one of these in the body.
func mayFail(_ name: Name = "checked") -> Statement {
    Statement(
        binding: .constant(name),
        expression: .cast(.literal(.int(0)), as: .ranged(.whole(from: 0, to: .through(255))), optional: false)
    )
}

// A reference from segment names, written directly. A path is what the language
// has, and the spelling belongs to whatever produced it.
func reference(_ names: Name...) -> Warp.Expression {
    .reference(Path(names.map { name in .key(name) }))
}

// MARK: - Running

// The entry name these tests link against. Any name would do, which procedure a
// run starts from is an argument, so there is nothing special about this one.
let entryName: Name = "entry"

// Link the set and run. The way a caller does it, and the way the model reads:
// the caller states its whole graph, then names one procedure in it.
func run(
    _ modules: [Module],
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
    environment: (any Environment)? = nil
) async throws -> Value {
    let builder = Builder()

    let image = try await builder.build(try modules.map { module in try module.publishing(entry) } + vocabulary)

    return try await Executor(environment: environment)
        .run(image, entry: entry, arguments: arguments)
}

// One module, for a test that wrote its whole graph as one.
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

// One procedure, linked alone or beside others. It is the entry, so it is
// public whatever the test wrote.
func run(
    _ procedure: Procedure,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard
) async throws -> Value {
    try await run(
        [
            try Module(
                procedures: others.merging([entryName: procedure.with(access: .public)]) { _, new in new }
            )
        ],
        arguments: arguments,
        vocabulary: vocabulary
    )
}

// What a body answers with, for the many tests that care about one value rather
// than a result map.
func answer(
    of body: Body,
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

// MARK: - Judging

func validates(
    _ expression: Warp.Expression,
    visible: Set<Name> = []
) -> Bool {
    validates(body: [Statement(binding: .constant("probe"), expression: expression)], visible: visible)
}

func validates(body: Body, visible: Set<Name> = []) -> Bool {
    do {
        try Validator().validate(body: body, visible: visible)

        return true
    } catch {
        return false
    }
}

// MARK: - Conditions

// Walking a collection is a loop over its count, so a test writing one writes
// the type a notation spells `each` with: the round's index against the
// material's count, and the element read at that index.
func walking(
    _ material: Path,
    element: Name,
    round: Name = "walk",
    body: Body
) -> Warp.Expression {
    .loop(
        while: .call(
            Call(
                selector: "std.math.lessThan",
                arguments: [
                    .reference([.key(round), .key("index")]),
                    .call(Call(selector: "std.collection.count", arguments: [.reference(material)]))
                ]
            )
        ),
        body: Block(
            body: Body([
                Statement(
                    binding: .constant(element),
                    expression: .reference(material.appending(contentsOf: [.indexRef([.key(round), .key("index")])]))
                )
            ] + body.statements)
        ),
        round: round
    )
}

// Equality is a procedure, so a test writing one writes the call the notation
// lowers to.
func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.logic.equal", arguments: [subject, operand]))
}

func differs(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.logic.notEqual", arguments: [subject, operand]))
}

// MARK: - Interpolation

// A template as the language holds one: pieces written one after another, each
// value asked how it reads. The notation spells this `{ format:, with: }` and
// lowers it to exactly this.
func interpolated(_ pieces: Warp.Expression...) -> Warp.Expression {
    .call(Call(selector: "std.text.joined", arguments: [.array(pieces), .literal(.string(""))]))
}

func literal(_ text: String) -> Warp.Expression {
    .literal(.string(text))
}

func spelling(_ value: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.text.text", arguments: [value]))
}

// MARK: - Refusal

func refusing(_ message: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.control.abort", arguments: [message]))
}

//
//  TestSupport.swift
//  WarpTestSupport
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp
import WarpStandard

// MARK: - Running

// The entry these tests run from.
public let entryName: Name = "entry"

// Build the set and run. The way a caller does it, and the way the model reads:
// the caller states its whole graph, then names one procedure in it.
public func run(
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
public func run(
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
public func run(
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

// A procedure held as a value, made the way a host gets one: a run whose
// entry answers a closure.
public func procedureValue() async throws -> Value {
    try await run(
        Procedure(
            signature: Signature(returns: .procedure(ProcedureType(returns: .null, failing: .these([])))),
            body: [returning(.closure(Procedure(body: [])))]
        )
    )
}

// What a body answers with, for the many tests that care about one value rather
// than a map of several. The body returns `value` after its statements, and
// unless a test says otherwise it may answer anything and fail with anything.
public func answer(
    of body: Body,
    returning value: Warp.Expression,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    signature: Signature = Signature(returns: .any, failing: .anything),
    vocabulary: [Module] = Module.standard
) async throws -> Value? {
    var returned = body

    returned.append(returning(value))

    return try await run(
        Procedure(signature: signature, body: returned),
        beside: others,
        arguments: arguments,
        vocabulary: vocabulary
    )
}

// MARK: - Judging

// What an expression reads is not a property it carries. The load walks
// structure and knows which names a body introduces, and a module is what it
// holds. Making one around the body is how a test asks the same question.
public func validates(
    _ expression: Warp.Expression,
    visible: Set<Name> = []
) -> Bool {
    validates(body: [Statement(binding: .constant("probe"), expression: expression)], visible: visible)
}

public func validates(body: Body, visible: Set<Name> = []) -> Bool {
    do {
        _ = try Module(
            constants: Dictionary(uniqueKeysWithValues: visible.map { name in (name, Warp.Expression.literal(.int(0))) }),
            procedures: [entryName: Procedure(body: body)]
        )

        return true
    } catch {
        return false
    }
}

// MARK: - Writing

// A reference from segment names, written directly. A path is what the language
// has, and the spelling belongs to whatever produced it.
public func reference(_ names: Name...) -> Warp.Expression {
    .reference(Path(names.map { name in .name(name) }))
}

// A map literal keyed by text: what a test answers several values at once
// with, each under its own key.
public func map(_ entries: [Name: Warp.Expression]) -> Warp.Expression {
    .dictionary(
        entries.sorted { one, other in one.key < other.key }.map { name, value in
            (key: .literal(.string(name.spelling)), value: value)
        }
    )
}

// A statement leaving the procedure with what it answers.
public func returning(_ value: Warp.Expression) -> Statement {
    Statement(expression: .leave(.procedure(value)))
}

// MARK: - Conditions

// Equality and the connectives are procedures, so a test writing one writes
// the call the notation lowers to.
public func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "Standard.Logic.equal", arguments: [subject, operand]))
}

public func differs(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "Standard.Logic.notEqual", arguments: [subject, operand]))
}

public func negating(_ condition: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "Standard.Logic.not", arguments: [condition]))
}

// A connective leaves its later sides unasked, so each arrives as something
// that has not been answered yet.
public func every(_ conditions: Warp.Expression...) -> Warp.Expression {
    chained("Standard.Logic.and", conditions)
}

public func some(_ conditions: Warp.Expression...) -> Warp.Expression {
    chained("Standard.Logic.or", conditions)
}

private func chained(_ selector: Name, _ conditions: [Warp.Expression]) -> Warp.Expression {
    .call(
        Call(
            selector: selector,
            arguments: [
                .array(
                    conditions.map { condition in
                        .closure(
                            Procedure(
                                signature: Signature(returns: .bool, constness: .const, isolation: .isolated),
                                body: [returning(condition)]
                            )
                        )
                    }
                )
            ]
        )
    )
}

// MARK: - Interpolation

// A template as the language holds one: pieces written one after another, each
// value asked how it reads. The notation spells this `{ format:, with: }` and
// lowers it to exactly this.
public func interpolated(_ pieces: Warp.Expression...) -> Warp.Expression {
    .call(Call(selector: "Standard.Text.joined", arguments: [.array(pieces), .literal(.string(""))]))
}

public func literal(_ text: String) -> Warp.Expression {
    .literal(.string(text))
}

public func spelling(_ value: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "Standard.Text.text", arguments: [value]))
}

// MARK: - Refusal

public func aborting(_ message: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "Standard.Control.abort", arguments: [message]))
}

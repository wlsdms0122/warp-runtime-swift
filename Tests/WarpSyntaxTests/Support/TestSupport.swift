//
//  TestSupport.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport
@testable import WarpSyntax
import WarpStandard

func path(_ text: String) -> Path {
    try! PathParser().parse(text)
}

// What an expression reads is not a property it carries. The validator walks
// structure and knows which names a body introduces. Asking it is how a test
// asks the same question.
func validates(
    _ expression: Warp.Expression,
    visible: Set<Name> = []
) -> Bool {
    do {
        try Validator().validate(
            Procedure(body: [Statement(binding: .constant("probe"), expression: expression)]),
            constants: visible
        )

        return true
    } catch {
        return false
    }
}

// MARK: - Loading and running

// The entry name these tests link against. Nothing is special about it, which
// procedure a run starts from is an argument to linking.
let entryName: Name = "entry"

func run(
    _ modules: [Module],
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
    environment: (any Environment)? = nil
) async throws -> Value {
    let image = try await Builder().build(try modules.map { module in try module.publishing(entry) } + vocabulary)

    return try await Executor(environment: environment)
        .run(image, entry: entry, arguments: arguments)
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

// MARK: - Conditions

// Equality and the connectives are procedures, so a test writing one writes the send
// the reader lowers to.
func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.logic.equal", arguments: [subject, operand]))
}

func differs(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.logic.notEqual", arguments: [subject, operand]))
}

func negating(_ condition: Warp.Expression) -> Warp.Expression {
    .call(Call(selector: "std.logic.not", arguments: [condition]))
}

// A connective leaves its later sides unasked, so each arrives as something that
// has not been answered yet.
func every(_ conditions: Warp.Expression...) -> Warp.Expression {
    chained("std.logic.and", conditions)
}

func some(_ conditions: Warp.Expression...) -> Warp.Expression {
    chained("std.logic.or", conditions)
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

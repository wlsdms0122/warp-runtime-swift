//
//  TestSupport.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// This target imports `Warp` and nothing else, on purpose. Every other test
// in the package reaches the language through a notation, which means it proves
// two things at once and cannot say which one broke. What is written here is
// the language on its own — procedures authored as Swift values, paths written as
// segments rather than parsed from text.

struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    let message = "the world did not cooperate"

    let type = "test"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

struct TestFatalError: WarpError {
    // MARK: - Property
    let message = "author mistake"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

// Fails on demand, so a test can ask what the language does with a failure
// without needing a world to fail in.
struct FailEffect: Effect {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation) async throws -> Value {
        guard invocation["recoverable"] == .bool(true) else {
            throw TestFatalError()
        }

        throw TestRecoverableFailure()
    }

    // MARK: - Private
}

// A reference from segment names, written directly — a path is what the language
// has, and the spelling belongs to whatever produced it.
func reference(_ names: Name...) -> Warp.Expression {
    .reference(names.map { name in .key(name) })
}

// MARK: - Running

// The entry name these tests link against. Any name would do — which procedure a
// run starts from is an argument, so there is nothing special about this one.
let entryName: Name = "entry"

// Link the set and run. The way a caller does it, and the way the model reads:
// the caller states its whole world, then names one procedure in it.
func run(
    _ modules: [Module],
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
    environment: (any Environment)? = nil
) async throws -> Value {
    let linker = Linker()

    let image = try linker.link(modules + vocabulary, entry: entry)

    return try await Executor(environment: environment)
        .run(image, arguments: arguments)
}

// One module, for a test that wrote its whole world as one.
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

// One procedure, linked alone or beside others.
func run(
    _ procedure: Procedure,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
) async throws -> Value {
    try await run(
        [try Module(procedures: others.merging([entryName: procedure]) { _, new in new })],
        arguments: arguments,
        vocabulary: vocabulary,
    )
}

// What a body answers with, for the many tests that care about one value rather
// than a result map.
func answer(
    of body: [Statement],
    result: Warp.Expression,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    signature: Signature = Signature(),
    vocabulary: [Module] = Module.standard,
) async throws -> Value? {
    try await run(
        Procedure(signature: signature, body: body, result: result),
        beside: others,
        arguments: arguments,
        vocabulary: vocabulary,
    )
}

// MARK: - Judging

func validates(
    _ expression: Warp.Expression,
    visible: Set<Name> = []
) -> Bool {
    validates(body: [Statement(binding: .constant("probe"), expression: expression)], visible: visible)
}

func validates(body: [Statement], visible: Set<Name> = []) -> Bool {
    do {
        try Validator().validate(body: body, visible: visible)

        return true
    } catch {
        return false
    }
}


// MARK: - Words a test brings

// Vocabulary is modules, so a test that needs a word declares one and puts it
// in the link.
extension Module {
    static let shouting = try! Module(
        procedures: [
            "app.shout": Procedure(
                signature: Signature(
                    parameters: ["text": Parameter(type: .string)],
                    returns: .string
                ),
                implementation: .effect(ShoutEffect())
            )
        ]
    )

    static let failing = try! Module(
        procedures: [
            "app.fail": Procedure(
                signature: Signature(
                    parameters: ["recoverable": Parameter(type: .bool, default: .bool(false))]
                ),
                implementation: .effect(FailEffect())
            )
        ]
    )
}

struct ShoutEffect: Effect {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation) async throws -> Value {
        .string(invocation.string("text")?.uppercased() ?? "")
    }

    // MARK: - Private
}



// Every procedure a list of modules declares, as two tables for two questions:
// what a selector names, and what a path segment reaches.

// MARK: - Conditions

// Equality and the connectives are words, so a test writing one writes the send
// the notation lowers to.
func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: subject, selector: "std.logic.equal", arguments: ["value": operand]))
}

func differs(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: subject, selector: "std.logic.notEqual", arguments: ["value": operand]))
}

func negating(_ condition: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: condition, selector: "std.logic.not"))
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
    .dispatch(
        Dispatch(
            receiver: .array(
                conditions.map { condition in
                    .closure(
                        Procedure(
                            implementation: .body(Block(body: [], result: condition)),
                            purity: .pure
                        )
                    )
                }
            ),
            selector: selector
        )
    )
}

// MARK: - Interpolation

// A template as the language holds one: pieces written one after another, each
// value asked how it reads. The notation spells this `{ format:, with: }` and
// lowers it to exactly this.
func interpolated(_ pieces: Warp.Expression...) -> Warp.Expression {
    .dispatch(Dispatch(receiver: .array(pieces), selector: "std.text.joined"))
}

func literal(_ text: String) -> Warp.Expression {
    .literal(.string(text))
}

func spelling(_ value: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: value, selector: "std.text.text"))
}

// MARK: - Refusal

func refusing(_ message: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: message, selector: "std.control.abort"))
}

extension Closure {
    // A closure a caller assembles in Swift: no body a document spelled, no
    // captures, claiming nothing. What a slot that asks nothing takes.
    static func assembled(answering result: Value? = nil, in table: ShapeTable = .empty) -> Closure {
        Closure(
            linked: Linked(
                label: "assembled",
                origin: 0,
                signature: Signature(),
                purity: .unstated,
                isolation: .unstated,
                implementation: .body(
                    Body(instructions: [], result: result.map(Code.literal)),
                    Frame(size: 0, parameters: [], variables: [], names: [])
                ),
                in: table
            ),
            captured: []
        )
    }
}

// The walk's answer as the tests ask it: what a path holds, or why the
// reading went wrong.
enum Lookup: Equatable {
    case found(Value)
    case unfit(reason: String)
}

extension Folding {
    func lookup(_ path: [PathSegment]) -> Lookup {
        do {
            return .found(try read(path, at: .given("test")))
        } catch let unfit as ReferenceUnfit {
            return .unfit(reason: unfit.reason)
        } catch {
            return .unfit(reason: "\(error)")
        }
    }
}

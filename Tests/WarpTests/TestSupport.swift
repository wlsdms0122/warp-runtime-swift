//
//  TestSupport.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// This target imports no notation, on purpose. Every other test in the
// package reaches the language through one, which means it proves two things
// at once and cannot say which one broke. What is written here is the language
// on its own: procedures authored as Swift values, paths written as segments
// rather than parsed from text. The standard vocabulary comes in because a
// program has to call somewhere, and what those procedures answer is tested where
// they live.

struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    let message = "the world did not cooperate"

    let type = TestRecoverableFailure.procedure

    static let procedure = "test"

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
    enum Parameters: Int, ParameterSet {
        case recoverable

        var name: Name { "recoverable" }

        var declared: Parameter { Parameter(type: .bool, default: .bool(false)) }
    }

    // MARK: - Property
    let failing = Failing.these([TestRecoverableFailure.procedure])

    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard invocation[.recoverable] == .bool(true) else {
            throw TestFatalError()
        }

        throw TestRecoverableFailure()
    }

    // MARK: - Private
}

// A statement that may fail and does not: a plain cast onto a shape the value
// already fits. An `attempt` stands only over a body that can fail, so a test
// showing what a rescue does *not* catch puts one of these in the body.
func mayFail(_ name: Name = "checked") -> Statement {
    Statement(
        binding: .constant(name),
        expression: .cast(.literal(.int(0)), as: .number, optional: false)
    )
}

// A reference from segment names, written directly. A path is what the language
// has, and the spelling belongs to whatever produced it.
func reference(_ names: Name...) -> Warp.Expression {
    .reference(names.map { name in .key(name) })
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

    let image = try builder.build(modules + vocabulary, entry: entry)

    return try await Executor(environment: environment)
        .run(image, arguments: arguments)
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

// One procedure, linked alone or beside others.
func run(
    _ procedure: Procedure,
    beside others: [Name: Procedure] = [:],
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard,
) async throws -> Value {
    try await run(
        [
            try Module(
                procedures: others.merging([entryName: procedure]) { _, new in new }
            )
        ],
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


// MARK: - Procedures a test brings

// Vocabulary is modules, so a test that needs a procedure declares one and puts it
// in the link.
extension Module {
    static let shouting = try! Module(
        procedures: [
            "app.shout": Procedure(
                signature: Signature(of: ShoutEffect.self, returns: .string),
                implementation: .effect(ShoutEffect())
            )
        ]
    )

    // A procedure that answers from a box it keeps between calls, and says so. Two
    // bodies calling it meet in that box.
    static let ticketing = try! Module(
        procedures: [
            "app.ticket": Procedure(
                signature: Signature(returns: .int),
                implementation: .query(TicketQuery())
            )
        ]
    )

    static let failing = try! Module(
        procedures: [
            "app.fail": Procedure(
                signature: Signature(of: FailEffect.self),
                implementation: .effect(FailEffect())
            )
        ]
    )
}

final class TicketQuery: Query, @unchecked Sendable {
    typealias Parameters = NoParameters

    // MARK: - Property
    let isolated = false

    private let lock = NSLock()
    private var issued = 0

    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<TicketQuery>) throws -> Value? {
        lock.lock()
        defer { lock.unlock() }

        issued += 1

        return .int(issued)
    }

    // MARK: - Private
}

struct ShoutEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case text

        var name: Name { "text" }

        var declared: Parameter { Parameter(type: .string) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        .string(invocation.string(.text)?.uppercased() ?? "")
    }

    // MARK: - Private
}



// Every procedure a list of modules declares, as two tables for two questions:
// what a selector names, and what a path segment reaches.

// MARK: - Conditions

// Walking a collection is a loop over its count, so a test writing one writes
// the shape a notation spells `each` with: the round's index against the
// material's count, and the element read at that index.
func walking(
    _ material: [PathSegment],
    element: Name,
    round: Name = "walk",
    body: [Statement]
) -> Warp.Expression {
    .loop(
        while: .call(
            Call(
                receiver: .reference([.key(round), .key("index")]),
                selector: "std.math.lessThan",
                arguments: [
                    "value": .call(Call(receiver: .reference(material), selector: "std.collection.count"))
                ]
            )
        ),
        body: Block(
            body: [
                Statement(
                    binding: .constant(element),
                    expression: .reference(material + [.indexRef([.key(round), .key("index")])])
                )
            ] + body
        ),
        round: round
    )
}

// Equality and the connectives are procedures, so a test writing one writes the call
// the notation lowers to.
func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(receiver: subject, selector: "std.logic.equal", arguments: ["value": operand]))
}

func differs(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .call(Call(receiver: subject, selector: "std.logic.notEqual", arguments: ["value": operand]))
}

func negating(_ condition: Warp.Expression) -> Warp.Expression {
    .call(Call(receiver: condition, selector: "std.logic.not"))
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
    .call(Call(receiver: .array(pieces), selector: "std.text.joined"))
}

func literal(_ text: String) -> Warp.Expression {
    .literal(.string(text))
}

func spelling(_ value: Warp.Expression) -> Warp.Expression {
    .call(Call(receiver: value, selector: "std.text.text"))
}

// MARK: - Refusal

func refusing(_ message: Warp.Expression) -> Warp.Expression {
    .call(Call(receiver: message, selector: "std.control.abort"))
}

extension Closure {
    // A closure a caller assembles in Swift: no body a document spelled, no
    // captures, claiming nothing. What a slot that asks nothing takes.
    static func assembled(answering result: Value? = nil, in table: LoweredTypeTable = .empty) -> Closure {
        Closure(
            origin: 0,
            number: 0,
            linked: Linked(
                label: "assembled",
                origin: 0,
                signature: Signature(),
                purity: .unstated,
                isolation: .unstated,
                failing: .unstated,
                implementation: .body(
                    Body(instructions: [], result: result.map(Operation.literal)),
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

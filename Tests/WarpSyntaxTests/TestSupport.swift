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

struct FailEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case recoverable

        var declared: Parameter { Parameter(name: "recoverable", type: .nullable(.bool)) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        guard invocation[.recoverable] == .bool(true) else {
            throw TestFatalError()
        }

        throw TestRecoverableFailure()
    }

    // MARK: - Private
}

struct FailForm: ConstructForm {
    // MARK: - Property
    static let key: Name = "fail"

    private let recoverable: Bool

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.recoverable = try decoder.singleValueContainer().decode(Bool.self)
    }

    // MARK: - Public
    func expression(boundTo id: String?) -> Warp.Expression {
        .call(
            Call(selector: "test.fail", arguments: [.literal(.bool(recoverable))])
        )
    }

    // MARK: - Private
}


func path(_ text: String) -> [PathSegment] {
    try! TemplateParser().parseRefPath(text)
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
            body: [Statement(binding: .constant("probe"), expression: expression)],
            visible: visible
        )

        return true
    } catch {
        return false
    }
}

// A caller registers on both sides: the procedure in the notation's registry, the
// declaration in a module. The split is the point. One says how a document
// spells it, the other says what answers.
extension Module {
    static let testing = try! Module(
        procedures: [
            "test.fail": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "recoverable", type: .bool)]
                ),
                implementation: .effect(FailEffect())
            )
        ]
    )
}

extension Loader {
    static let testing = Loader(
        registry: try! ConstructRegistry.standard.registering(FailForm.self)
    )
}


// MARK: - Loading and running

// The entry name these tests link against. Nothing is special about it, which
// procedure a run starts from is an argument to linking.
let entryName: Name = "entry"

extension Loader {
    // Reading a document without saying which document it is. These tests are
    // about what a reader accepts, not about pointing a refusal back into the
    // file it came from, so there is nothing here to name.
    func load(_ value: Value) throws -> Module {
        try load(value, identity: nil)
    }

    // A document as a front end hands one over: written in this notation's
    // spellings, lowered, and only then read. The two calls are the two
    // questions (what a text spells, and whether its program holds) and the
    // reading is handed a document with no spellings left in it.
    //
    // The version is filled in, which nobody writes by hand. A fixture that
    // sends procedures still writes its own `imports`: what a program takes from
    // its link is the author's to say, and a helper that said it for them
    // would make every fixture's list true by construction.
    //
    // Tests about the envelope itself call `load` directly, because for those
    // the envelope is the subject rather than the ceremony.
    func loadDocument(_ value: Value, from notation: Notation = .testing) throws -> Module {
        guard case let .dictionary(document) = value else { return try load(value, identity: nil) }

        var written = document

        if written[Envelope.versionKey] == nil {
            written = written.writing(Envelope.versionKey, with: .int(Envelope.version))
        }

        if written[Envelope.importsKey] == nil {
            written = written.writing(Envelope.importsKey, with: .array([]))
        }

        // The entry is named outside the text, so the text is not where its
        // word is written.
        return try load(try canonical(.dictionary(written), from: notation), identity: nil).publishing(entryName)
    }

    // Most tests here are about one construct or one reader, not about the
    // envelope a module is written in, so they write a procedure's body and this
    // names it. What the envelope itself accepts is `ModuleNotationTests`.
    //
    // The fixture is a `Value` because that is what a loader takes. Writing
    // YAML here would import a front end, and then a parser bug could fail a
    // reader's test. The imports are supposed to say which layer a test is
    // about.
    func loadProcedure(
        _ value: Value,
        named name: Name = entryName,
        importing imports: [Name] = [],
        from notation: Notation = .testing
    ) throws -> Module {
        try loadDocument(
            [
                "imports": .array(imports.map { name in .string(name.spelling) }),
                "procedures": [name: value]
            ],
            from: notation
        )
    }
}

func run(
    _ modules: [Module],
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard + [.testing],
    environment: (any Environment)? = nil
) async throws -> [Name: Value] {
    let image = try await Builder().build(try modules.map { module in try module.publishing(entry) } + vocabulary)

    let answer = try await Executor(environment: environment)
        .run(image, entry: entry, arguments: arguments)

    // This notation spells several named outputs, which the reader lowers to
    // one record, so a test that asks about `outputs["x"]` is asking about a
    // field of the answer, and unwrapping here keeps that phrasing.
    guard let outputs = answer.asDictionary else { return [:] }

    return Dictionary(uniqueKeysWithValues: outputs.entries.map { entry in (entry.name, entry.value) })
}


func run(
    _ module: Module,
    entry: Name = entryName,
    arguments: [Name: Value] = [:],
    vocabulary: [Module] = Module.standard + [.testing],
    environment: (any Environment)? = nil
) async throws -> [Name: Value] {
    try await run(
        [module],
        entry: entry,
        arguments: arguments,
        vocabulary: vocabulary,
        environment: environment
    )
}

// Every procedure a list of modules declares, as two tables for two questions:
// what a selector names, and what a path segment reaches.

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

extension Closure {
    // A closure a caller assembles in Swift: no body a document spelled, no
    // captures, claiming nothing.
    static func assembled() -> Closure {
        Closure(
            writer: Closure.Writer(document: .compiled(Compiled.Token()), name: "assembled"),
            nth: 0,
            linked: Linked(
                label: "assembled",
                origin: 0,
                signature: Signature(),
                access: .internal,
                constness: .unstated,
                isolation: .unstated,
                failing: .unstated,
                implementation: .body(
                    Body(instructions: [], result: nil),
                    Frame(size: 0, parameters: [], variables: [], captures: [], names: [])
                ),
                foldable: true,
                in: .empty
            ),
            captured: []
        )
    }
}

extension Folding {
    // A condition read here, as the bool it answers.
    func evaluate(_ condition: Warp.Expression) async throws -> Bool {
        guard case let .bool(answer) = try await read(condition) else {
            throw ReadingError("a condition must answer bool")
        }

        return answer
    }
}


// A test's image runs from the test's entry unless the test names another.
extension Executor {
    func run(_ image: Image, arguments: [Name: Value] = [:]) async throws -> Value {
        try await run(image, entry: entryName, arguments: arguments)
    }
}

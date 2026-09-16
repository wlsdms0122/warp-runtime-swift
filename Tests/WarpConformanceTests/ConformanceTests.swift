//
//  ConformanceTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
import Warp
import WarpStandard
import WarpSyntax

// The specification's cases, run against this implementation.
//
// Every other test here reaches inside (`@testable`, private types, internal
// helpers) which is right for a test about how something is built. These are
// about something else: whether this is the language `spec/` describes. So this
// file imports what any caller imports and nothing more. A runner that could
// see inside could pass by agreeing with the implementation rather than with
// the specification, which is the one thing it must not be able to do.
//
// The cases are data, and the point of that is that this file is replaceable.
// An implementation in another language writes its own runner (this much code)
// and asks the same questions.
@Suite("The specification's cases")
struct ConformanceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every case in the specification", arguments: try Case.all())
    func specificationCase(_ sut: Case) async throws {
        switch sut.expectation {
        case let .answers(expected):
            let answered = try await run(sut)

            #expect(answered == expected, "\(sut.name): \(sut.note)")

        case let .refuses(stage):
            let reached = try await reached(sut)

            #expect(reached == stage, "\(sut.name): \(sut.note)")
        }
    }

    @Test("the cases are the specification's, and it has some")
    func thereAreCases() throws {
        // Given. A suite that silently found nothing would pass, and passing by
        // asking nothing is the failure mode a conformance suite has
        let sut = try Case.all()

        #expect(sut.count >= 10)
        #expect(Set(sut.map(\.name)).count == sut.count)

        // A case is found by its name: a diff names the file and a failure names
        // the case, and a reader who has one goes looking for the other. Where
        // the two drift apart the case is still asked and still nobody finds it.
        let adrift = sut.filter { one in one.name != one.file }.map { one in "\(one.file) says '\(one.name)'" }

        #expect(adrift.isEmpty, "a case is named what its file is: \(adrift.joined(separator: ", "))")
    }

    // MARK: - Public
    // MARK: - Private
    private func run(_ sut: Case) async throws -> Value {
        let builder = Builder()
        let image = try await builder.build(try sut.modules(), entry: "entry")

        return try await Executor().run(image, arguments: sut.arguments)
    }

    // How far a case got before it was refused. The stage is part of the answer:
    // stopping at a run what another implementation stops at a build means
    // something already happened, and what already happened cannot be taken back.
    private func reached(_ sut: Case) async throws -> Case.Stage? {
        let builder = Builder()
        let vocabulary = try await sut.brought
        let module: Module

        // The case's own document is read apart from the rest, because a
        // document that does not read is the answer to this question and a
        // vocabulary that does not read is a case nobody can ask.
        do {
            module = try Loader().load(sut.program, identity: nil)
        } catch {
            return .load
        }

        let modules = vocabulary + [module] + Module.standard

        let image: Image

        do {
            image = try await builder.build(modules, entry: "entry")
        } catch {
            return .build
        }

        do {
            _ = try await Executor().run(image, arguments: sut.arguments)
        } catch {
            return .run
        }

        return nil
    }
}

// One question, read from the specification rather than written here.
//
// A case is not a program and is not written in the form of one. It is spelled
// in the same text (the encoding carries a tree and never learns what a tree
// means, so there is one of those and not two) but what it holds under `test`
// is a test, and the document it asks about is nested whole under `program`.
//
// Which is what lets the two be told apart by saying so rather than by noticing:
// a case declares `test`, a document declares `warp`, and each is refused by the
// other's reader for what it is instead of for the keys it happens to carry.
struct Case: Sendable, CustomStringConvertible {
    // Which types a runner has to understand to ask these questions. It moves
    // for the same reason `warp` does and on its own schedule. The day a case
    // may say something new is not the day a document may.
    static let version = 3
    static let earliest = 2

    static let versionKey: Name = "test"

    enum Stage: String, Sendable {
        case load
        case build
        case run
    }

    enum Expectation: Sendable {
        case answers(Value)
        case refuses(Stage)
    }

    // A module the runner brings. The declarations are held apart from the rest
    // of it because each carries keys a declaration does not.
    struct Vocabulary: Sendable {
        // What a runner says for itself: the version this module is read at,
        // and that its declarations send nothing. A case writing either is
        // refused rather than quietly overruled.
        static let runnersKeys: Set<Name> = ["warp", "imports"]

        // The module as the reader takes it.
        let module: Value

        let procedures: [Supplied]
    }

    // One procedure a case asks for. Its declaration is written the way any
    // procedure's is, so a runner reads it with the reader it already has; what
    // is written beside it is what a body would otherwise have shown.
    //
    // The names it may declare are `of` and `value`, in that order, because a
    // procedure the host answers reads its arguments at fixed places and a case
    // cannot invent a place in someone else's runner.
    struct Supplied: Sendable {
        static let ownKeys: Set<Name> = ["answers", "runs", "isolated", "failing"]

        let name: Name

        // The declaration alone, ready for the reader every runner has.
        let declaration: Value

        // What it answers, whatever it is sent. A case asks about what a
        // declaration permits, not about arithmetic, so one answer is enough.
        let answers: Value

        // Whether it reaches outside the run. One that does not is what a
        // constant may settle from, what a `pure procedure` slot takes, and
        // what an operand may call.
        let runs: Bool

        let isolated: Bool
        let failing: [String]
    }

    // MARK: - Property
    let name: String

    // The file this was read from, without the suffix every case wears.
    let file: String

    let note: String
    let program: Value
    let arguments: [Name: Value]
    let expectation: Expectation

    // The module this case asks the runner to bring, which is what a host does
    // for every program: the document names what it needs and the code arrives
    // at the link. A case cannot write host code, so it writes what the link
    // needs to know about it, and every runner can build that much. Nil where
    // the case asks for none.
    let vocabulary: Vocabulary?

    var description: String { name }

    // MARK: - Initializer
    init(from written: Value, in file: String) throws {
        self.file = file

        // The version first, and before the type, for the reason a document
        // reads its own first: a later case may say something this runner has
        // no name for, and "I am too old for this" is a different answer from
        // "this is not a case".
        guard let declared = written[Self.versionKey] else {
            throw ConformanceError(
                "this is not a case. It does not say which test it is written for"
                    + " (`\(Self.versionKey)`)"
            )
        }

        // Said, but not as a number. A different answer from the one above: that
        // one is "this is not a case", and this one is "this is a case and it is
        // wrong", which is the distinction the check exists to keep.
        guard case let .int(version) = declared else {
            throw ConformanceError(
                "a case says which test it is written for as a whole number,"
                    + " and this says \(declared)"
            )
        }

        guard (Self.earliest ... Self.version).contains(version) else {
            throw ConformanceError(
                "this case is written for test \(version),"
                    + " and this reads \(Self.earliest) through \(Self.version)"
            )
        }

        guard
            case let .string(name)? = written["name"],
            case let .string(note)? = written["note"],
            let program = written["program"]
        else {
            throw ConformanceError("a case is a name, a note, a program and what should happen")
        }

        self.name = name
        self.note = note
        self.program = program

        if case let .dictionary(arguments)? = written["arguments"] {
            self.arguments = Dictionary(
                uniqueKeysWithValues: arguments.entries.map { entry in (entry.name, entry.value) }
            )
        } else {
            self.arguments = [:]
        }

        // One of `answers` or `refuses`, and exactly one. The slot groups them
        // so that this is a question about one record instead of a rule about
        // two sibling keys, but a record is not a choice, so the count is still
        // counted here. A case edited from one to the other and left holding
        // both would otherwise start asking a different question than it reads
        // as, and nobody would be told.
        guard
            case let .dictionary(expect)? = written["expect"],
            expect.count == 1,
            let (held, expected) = expect.entries.first
        else {
            throw ConformanceError("a case expects exactly one of `answers` or `refuses`")
        }

        self.vocabulary = try Self.supplied(in: written["vocabulary"])

        switch held {
        case "refuses":
            guard case let .string(stage) = expected, let stage = Stage(rawValue: stage) else {
                throw ConformanceError("\(expected) is not a stage a program is refused at")
            }

            self.expectation = .refuses(stage)

        case "answers":
            self.expectation = .answers(expected)

        default:
            throw ConformanceError(
                "a case expects what it answers or where it is refused, and not `\(held)`"
            )
        }
    }

    // MARK: - Public
    private static func supplied(in written: Value?) throws -> Vocabulary? {
        guard let written else { return nil }

        guard case let .dictionary(module) = written, case let .dictionary(entries)? = module["procedures"] else {
            throw ConformanceError(
                "the vocabulary a case asks for is a module, and a module declares procedures"
            )
        }

        if let taken = module.names.first(where: Vocabulary.runnersKeys.contains) {
            throw ConformanceError(
                "the vocabulary a case asks for writes '\(taken)', which is the"
                    + " runner's to say. A case says what the module declares and"
                    + " nothing about how it is read"
            )
        }

        let procedures: [Supplied] = try entries.entries.map { entry in
            guard case let .dictionary(record) = entry.value else {
                throw ConformanceError("'\(entry.name)' is written the way a procedure is")
            }

            let declaration = Value.dictionary(
                Dictionary(
                    uniqueKeysWithValues: record.entries
                        .filter { field in !Supplied.ownKeys.contains(field.name) }
                        .map { field in (field.name, field.value) }
                )
            )

            return Supplied(
                name: entry.name,
                declaration: declaration,
                answers: record["answers"] ?? .null,
                runs: record["runs"] == .bool(true),
                isolated: record["isolated"] != .bool(false),
                failing: {
                    guard case let .array(named)? = record["failing"] else { return [] }

                    return named.compactMap { held in
                        guard case let .string(type) = held else { return nil }

                        return type
                    }
                }()
            )
        }

        // The module as the reader takes it: what the case wrote, with the
        // declarations stripped of the keys that are the host's rather than the
        // document's, and the three the runner says for itself.
        let stripped = Value.dictionary(
            Dictionary(uniqueKeysWithValues: module.entries.map { field in (field.name, field.value) })
                .merging([
                    "warp": .int(1),
                    "imports": .array([]),
                    "procedures": .dictionary(
                        Dictionary(
                            uniqueKeysWithValues: procedures.map { one in (one.name, one.declaration) }
                        )
                    )
                ]) { _, made in made }
        )

        return Vocabulary(module: stripped, procedures: procedures)
    }

    // The cases live beside the specification they belong to rather than inside
    // this package, because they are not this implementation's. The day there
    // is a second implementation they move with `spec/` and this file stays.
    // MARK: - Internal
    // Every module this case stands on: what the host was asked to bring, the
    // case's own document, and the standard vocabulary. The case describes the
    // vocabulary it asked for, so building it is the case's own answer and not
    // a runner's.
    func modules() async throws -> [Module] {
        try await brought + [try Loader().load(program, identity: nil)] + Module.standard
    }

    // The vocabulary the case asked the runner for, as a module standing in
    // front of the case's own document so that what the host brings is there
    // to be named. Empty where the case asked for none.
    var brought: [Module] {
        get async throws {
            guard let vocabulary else { return [] }

            let loader = Loader()

            // The declarations go through the reader every document goes through,
            // because they are declarations. What arrives is read as a body, and
            // the implementation is swapped for the one the case described: a body
            // is what a document can write and a host procedure is what it cannot.
            let declared = try loader.load(vocabulary.module, identity: nil)

            let brought = try Module(
                types: declared.types,
                constraints: declared.constraints,
                contracts: declared.contracts,
                claims: declared.claims,
                procedures: Dictionary(
                    uniqueKeysWithValues: try vocabulary.procedures.map { one in
                        guard let read = declared.procedures[one.name] else {
                            throw ConformanceError("'\(one.name)' was asked for and did not read")
                        }

                        return (one.name, try supplied(one, declaring: read.signature))
                    }
                )
            )

            return [brought]
        }
    }

    // The host's side of one asked-for procedure. Which door it answers through
    // is the claim it makes: the one that answers without running is handed no
    // way to reach outside, and the other is.
    private func supplied(_ one: Supplied, declaring signature: Signature) throws -> Procedure {
        Procedure(
            signature: signature,
            implementation: door(one, reading: try places(signature.parameters.count))
        )
    }

    // Which of the fixed place sets this declaration reads its arguments
    // through. A case declares `of` and `value` and nothing else, so the
    // arity picks one.
    private func places(_ count: Int) throws -> any ParameterSet.Type {
        switch count {
        case 0:
            return NoParameters.self

        case 1:
            return OneName.self

        case 2:
            return TwoNames.self

        default:
            throw ConformanceError(
                "a procedure a case asks for declares \(count) names, and the places"
                    + " a case may name are `of` and `value`"
            )
        }
    }

    // Which door it answers through, which is the claim it makes about
    // reaching outside the run.
    private func door(_ one: Supplied, reading places: any ParameterSet.Type) -> Implementation {
        func made<Parameters: ParameterSet>(_: Parameters.Type) -> Implementation {
            one.runs
                ? .effect(
                    SuppliedEffect<Parameters>(
                        answers: one.answers,
                        isolated: one.isolated,
                        failing: .these(Set(one.failing))
                    )
                )
                : .query(
                    SuppliedQuery<Parameters>(
                        answers: one.answers,
                        isolated: one.isolated,
                        failing: .these(Set(one.failing))
                    )
                )
        }

        return made(places)
    }

    static func all() throws -> [Case] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WarpConformanceTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // warp-runtime-swift
            .deletingLastPathComponent()   // runtime
            .deletingLastPathComponent()   // the repository
            .appendingPathComponent("spec")
            .appendingPathComponent("conformance")

        // The cases are the ones named like cases, and everything else in the
        // folder is somebody else's business. A `.DS_Store`, a `.orig` left by
        // a merge, a copy someone kept while editing. A runner that refused to
        // start over any of those would be putting "is this folder tidy" and
        // "is this implementation the language" behind one red light, and the
        // second question is the only one it was built to ask.
        //
        // The cost is real and is accepted: a case saved under a name this
        // misses is not asked, and nothing here says so. What catches that is
        // the same thing that catches a case deleted outright. It is a file in
        // a diff, and the dumper that writes these names them.
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { file in file.lastPathComponent.hasSuffix(".test.warpt") }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }

        return try files.map { file in
            try Case(
                from: try TextEncoding.value(from: try Data(contentsOf: file)),
                in: String(file.lastPathComponent.dropLast(".test.warpt".count))
            )
        }
    }

    // MARK: - Private
}

struct ConformanceError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}


// The names a procedure a case asks for may declare, in the order a
// declaration's names stand in. A case cannot invent a place in someone else's
// runner, so the places are fixed here and the spec says which they are.
enum OneName: Int, ParameterSet {
    case of

    var name: Name { "of" }

    var declared: Parameter { Parameter(type: .any) }
}

enum TwoNames: Int, ParameterSet {
    case of
    case value

    var name: Name {
        switch self {
        case .of:
            return "of"

        case .value:
            return "value"
        }
    }

    var declared: Parameter { Parameter(type: .any) }
}

// A procedure a case asked for that answers without running. What it answers is
// the case's, and it is the same every time: a case asks what a declaration
// permits, not what arithmetic does.
struct SuppliedQuery<Parameters: ParameterSet>: Query {
    let answers: Value
    let isolated: Bool
    let failing: Failing

    func evaluate(_ question: Question<Self>) async throws -> Value? {
        answers
    }
}

// The same, through the door that reaches outside the run.
struct SuppliedEffect<Parameters: ParameterSet>: Effect {
    let answers: Value
    let isolated: Bool
    let failing: Failing

    func run(_ invocation: Invocation<Self>) throws -> Value {
        answers
    }
}

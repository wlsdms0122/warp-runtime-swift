//
//  Case.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

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
    enum Stage: String, Sendable {
        case load
        case build
        case run
    }

    // What a program may expect: to run and answer, to be refused at a stage,
    // or to compile to exactly this object.
    enum Expectation: Sendable {
        case answers(Value)
        case refuses(Stage)
        case builds(Value)
    }

    // An object the runner reads, links with the standard vocabulary and runs,
    // with what the entry is given. What it leans on is written inside it, so
    // it asks the runner to bring nothing.
    struct Object: Sendable {
        // What an object may expect: it is read, linked and run, so it answers
        // or is refused at a stage, and builds nothing.
        enum Outcome: Sendable {
            case answers(Value)
            case refuses(Stage)
        }

        // MARK: - Property
        let written: Value
        let arguments: [Name: Value]
        let expectation: Outcome

        // The identity the case reads the object under, where the case says
        // one; the object's own where it says none. A host keeps an object
        // under a document and hands that back, and a case that hands back
        // another asks whether the reading notices.
        let document: Identity?

        var identity: Identity? {
            if let document { return document }

            guard
                case let .dictionary(object) = written,
                case let .array(held)? = object["document"],
                case let .bytes(bytes)? = held.first
            else { return nil }

            return Identity(bytes)
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // A document in one of its encodings, as the bytes that arrived, which
    // are read and nothing else.
    enum Encoded: Sendable {
        case binary(Data)
        case text(Data)

        // MARK: - Property
        var data: Data {
            switch self {
            case let .binary(data), let .text(data): data
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        func read() throws -> Value {
            switch self {
            case let .binary(data): try BinaryEncoding().value(from: data)
            case let .text(data): try TextEncoding().value(from: data)
            }
        }

        func written(_ value: Value) throws -> Data {
            switch self {
            case .binary: try BinaryEncoding().data(from: value)
            case .text: try TextEncoding().data(from: value)
            }
        }

        // MARK: - Private
    }

    // What an encoding may expect: to read as a value; to read as a value
    // that writes back as exactly this, which is what a writer is held to;
    // or to be refused where it is read, which is the one stage it reaches.
    enum Reading: Sendable {
        case reads(Value)
        case spells(Value)
        case refuses
    }

    // A document the runner reads, builds and runs, with what it is given and
    // what the runner brings.
    struct Program: Sendable {
        // MARK: - Property
        let document: Value
        let arguments: [Name: Value]

        // The module this case asks the runner to bring, which is what a host
        // does for every program: the document names what it needs and the
        // code arrives at the link. A case cannot write host code, so it
        // writes what the link needs to know about it, and every runner can
        // build that much. Nil where the case asks for none.
        let vocabulary: Vocabulary?

        // The documents laid beside the program, read the way the program is.
        // A rule about two documents is asked with the program and one of
        // these. Empty where the case lays none.
        let beside: [Module]

        let expectation: Expectation

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
                let identity = try Identity.of(vocabulary.module)
                let declared = try loader.load(vocabulary.module, identity: identity)

                let brought = try Module(
                    types: declared.types,
                    contracts: declared.contracts,
                    claims: declared.claims,
                    members: declared.members,
                    procedures: Dictionary(
                        uniqueKeysWithValues: try vocabulary.procedures.map { one in
                            guard let read = declared.procedures[one.name] else {
                                throw ConformanceError("'\(one.name)' was asked for and did not read")
                            }

                            return (one.name, try supplied(one, declaring: read))
                        }
                    ),
                    identity: identity
                )

                return [brought]
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // Every module this case stands on: what the host was asked to bring, the
        // case's own document, and the standard vocabulary. The case describes the
        // vocabulary it asked for, so building it is the case's own answer and not
        // a runner's.
        func modules() async throws -> [Module] {
            try await brought + beside + [try Loader().load(document, identity: try Identity.of(document))] + Module.standard
        }

        // MARK: - Private
        // The host's side of one asked-for procedure. Which door it answers through
        // is the claim it makes: the one that answers without running is handed no
        // way to reach outside, and the other is.
        private func supplied(_ one: Case.Supplied, declaring read: Procedure) throws -> Procedure {
            Procedure(
                access: read.access,
                signature: read.signature,
                implementation: door(one, reading: try places(read.signature.parameters.map(\.name)))
            )
        }

        // Which of the fixed place sets this declaration reads its arguments
        // through, which its names pick.
        private func places(_ declared: [Name]) throws -> any ParameterSet.Type {
            switch declared {
            case []:
                return NoParameters.self

            case ["first"]:
                return OneName.self

            case ["first", "second"]:
                return AnyPair.self

            default:
                throw ConformanceError(
                    "a procedure a case asks for declares"
                        + " \(declared.map(\.spelling).joined(separator: ", ")), and the places"
                        + " a case may name are `first` and `second`, in that order"
                )
            }
        }

        // Which door it answers through, which is the claim it makes about
        // reaching outside the run.
        private func door(_ one: Case.Supplied, reading places: any ParameterSet.Type) -> Implementation {
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
    }

    // What a case asks: a program and what it should do, or an encoding and
    // what it should read as. Each half carries only what it can expect, so
    // no check outside the type keeps them apart.
    enum Asked: Sendable {
        case program(Program)
        case encoded(Encoded, Reading)
        case object(Object)
    }

    // A module the runner brings. The declarations are held apart from the rest
    // of it because each carries keys a declaration does not.
    struct Vocabulary: Sendable {
        // MARK: - Property
        // What a vocabulary writes: what the host's procedures are, the types,
        // contracts and extensions their signatures stand on, a member being
        // one of the host's procedures, and what it uses from other modules,
        // as any module lists it. Which version it is read
        // at is the runner's to say, and what a program declares beside them
        // (constants, variables) is a document's.
        static let declaringKeys: Set<Name> = ["imports", "types", "contracts", "extensions", "procedures"]

        // The module as the reader takes it.
        let module: Value

        let procedures: [Supplied]

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // One procedure a case asks for. Its declaration is written the way any
    // procedure's is, so a runner reads it with the reader it already has; what
    // is written beside it is what a body would otherwise have shown.
    //
    // The names it may declare are `first` and `second`, in that order, because a
    // procedure the host answers reads its arguments at fixed places and a case
    // cannot invent a place in someone else's runner.
    struct Supplied: Sendable {
        // MARK: - Property
        static let ownKeys: Set<Name> = ["answers", "runs", "isolated", "failing"]

        let name: Name

        // The declaration alone, ready for the reader every runner has.
        let declaration: Value

        // What it answers, whatever it is sent. A case asks about what a
        // declaration permits, not about arithmetic, so one answer is enough.
        let answers: Value

        // Whether it reaches outside the run. One that does not is what a
        // constant may settle from, what a `const Procedure` slot takes, and
        // what an operand may call.
        let runs: Bool

        let isolated: Bool
        let failing: [String]

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // Which types a runner has to understand to ask these questions. It moves
    // for the same reason `warp` does and on its own schedule.
    static let version = 1

    // The specification's folder. The cases live in its `conformance`,
    // beside the pages they belong to, since they are the language's and not
    // this implementation's.
    static let specification = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Case
        .deletingLastPathComponent()   // WarpConformanceTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // warp-runtime-swift
        .deletingLastPathComponent()   // runtime
        .deletingLastPathComponent()   // the repository
        .appendingPathComponent("spec")

    // What a case's file is named with after the case's name.
    static let suffix = ".test.warpt"

    static let versionKey: Name = "test"

    let name: String

    // The file this was read from, without the suffix every case wears.
    let file: String

    let note: String

    let asked: Asked

    var description: String { name }

    // MARK: - Initializer
    init(from read: Value, in file: String) throws {
        self.file = file

        // The version first, and before the type, for the reason a document
        // reads its own first: a later case may say something this runner has
        // no name for, and "I am too old for this" is a different answer from
        // "this is not a case".
        guard case let .dictionary(written) = read, let declared = written[Self.versionKey] else {
            throw ConformanceError(
                "this is not a case. It does not say which test it is written for"
                    + " (`\(Self.versionKey)`)"
            )
        }

        // Said, but not as a number: a case, and a wrong one.
        guard case let .int(version) = declared else {
            throw ConformanceError(
                "a case says which test it is written for as a whole number,"
                    + " and this says \(declared)"
            )
        }

        guard version == Self.version else {
            throw ConformanceError(
                "this case is written for test \(version), and this reads test \(Self.version)"
            )
        }

        guard
            case let .string(name)? = written["name"],
            case let .string(note)? = written["note"]
        else {
            throw ConformanceError("a case is a name, a note, a subject and what should happen")
        }

        self.name = name
        self.note = note

        // One of `answers`, `reads`, `spells`, `builds` or `refuses`, and
        // exactly one: a mapping is not a choice, so the count is counted here.
        guard
            case let .dictionary(expect)? = written["expect"],
            expect.count == 1,
            let (held, expected) = try expect.named().first
        else {
            throw ConformanceError("a case expects exactly one of `answers`, `reads`, `spells`, `builds` and `refuses`")
        }

        // A case asks about a program, about bytes, about text or about an
        // object, and a case holding two would be two cases sharing one
        // answer. What it asks about decides what it may expect: an encoding
        // is read and nothing else, so it reads as a value or is refused where
        // it is read; a program runs, so it answers or is refused at a stage,
        // or it builds, and what it builds is an object; an object is read,
        // linked and run, so it answers or is refused.
        switch (written["program"], written["bytes"], written["text"], written["object"]) {
        case let (document?, nil, nil, nil):
            try Self.reads(written, ["program", "arguments", "vocabulary", "documents"], about: "a program")

            let expectation: Expectation

            switch held {
            case "answers":
                expectation = .answers(expected)

            case "refuses":
                expectation = .refuses(try Self.stage(expected))

            case "builds":
                expectation = .builds(expected)

            case "reads", "spells":
                throw ConformanceError("a program answers, builds or is refused; only bytes and text read as a value")

            default:
                throw ConformanceError("a case expects what it answers, what it builds or where it is refused, and not `\(held)`")
            }

            self.asked = .program(
                Program(
                    document: document,
                    arguments: try Self.given(written["arguments"], of: name),
                    vocabulary: try Self.supplied(in: written["vocabulary"]),
                    beside: try Self.beside(written["documents"]),
                    expectation: expectation
                )
            )

        case let (nil, .bytes(bytes)?, nil, nil):
            self.asked = try Self.encoded(.binary(Data(bytes)), expecting: held, expected, in: written)

        case (nil, .some, nil, nil):
            throw ConformanceError("the bytes a case asks about are written as bytes")

        // A text is written as a string, or as bytes where the question is
        // whether those bytes are text at all.
        case let (nil, nil, .string(text)?, nil):
            self.asked = try Self.encoded(.text(Data(text.utf8)), expecting: held, expected, in: written)

        case let (nil, nil, .bytes(bytes)?, nil):
            self.asked = try Self.encoded(.text(Data(bytes)), expecting: held, expected, in: written)

        case (nil, nil, .some, nil):
            throw ConformanceError("the text a case asks about is written as a String, or as bytes")

        // An object leans on what is written inside it, so it asks the runner
        // to bring nothing and lay nothing beside it.
        case let (nil, nil, nil, object?):
            try Self.reads(written, ["object", "arguments", "document"], about: "an object")

            let expectation: Object.Outcome

            switch held {
            case "answers":
                expectation = .answers(expected)

            case "refuses":
                expectation = .refuses(try Self.stage(expected))

            default:
                throw ConformanceError("an object answers or is refused, and not `\(held)`")
            }

            let document: Identity?

            switch written["document"] {
            case nil: document = nil
            case let .bytes(bytes)?: document = Identity(bytes)
            default: throw ConformanceError("the document a case reads an object under is written as bytes")
            }

            self.asked = .object(
                Object(
                    written: object,
                    arguments: try Self.given(written["arguments"], of: name),
                    expectation: expectation,
                    document: document
                )
            )

        default:
            throw ConformanceError("a case asks about exactly one of a `program`, `bytes`, `text` and `object`")
        }
    }

    // MARK: - Public
    static func all() throws -> [Case] {
        try files().map { file in
            try Case(
                from: try TextEncoding().value(from: try Data(contentsOf: file)),
                in: String(file.lastPathComponent.dropLast(suffix.count))
            )
        }
    }

    // The cases are the files named like cases, and nothing else in the
    // folder is read, so a case saved under another name is not asked.
    static func files() throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: specification.appendingPathComponent("conformance"), includingPropertiesForKeys: nil)
            .filter { file in file.lastPathComponent.hasSuffix(suffix) }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }
    }

    // MARK: - Private
    // The documents a case lays beside its program. A list of mappings, each a
    // document that reads; anything else is a case no two runners would read
    // alike. One that does not read is the case's own fault, since the
    // question was about the program.
    private static func beside(_ written: Value?) throws -> [Module] {
        guard let written else { return [] }

        guard case let .array(documents) = written, documents.allSatisfy({ document in
            if case .dictionary = document { return true }

            return false
        }) else {
            throw ConformanceError("the documents a case lays beside its program are a list of documents")
        }

        return try documents.map { document in
            do {
                return try Loader().load(document, identity: try Identity.of(document))
            } catch {
                throw ConformanceError("a document laid beside the program does not read: \(error)")
            }
        }
    }

    private static func stage(_ expected: Value) throws -> Stage {
        guard case let .string(stage) = expected, let stage = Stage(rawValue: stage) else {
            throw ConformanceError("\(expected) is not a stage a program is refused at")
        }

        return stage
    }

    // A case holds what every case writes and the keys its subject reads, and
    // nothing else: a key outside them, a misspelled one included, is a
    // question the runner would not ask.
    private static func reads(_ fields: Value.Dictionary, _ subject: Set<Name>, about named: String) throws {
        let every: Set<Name> = [versionKey, "name", "note", "expect"]

        if let (key, _) = try fields.named().first(where: { key, _ in !every.contains(key) && !subject.contains(key) }) {
            throw ConformanceError("a case about \(named) writes `\(key)`, which it does not read")
        }
    }

    // An encoding is read and nothing is run, so nothing is given, brought,
    // laid beside it or read under an identity. A case writing any of those
    // asked something the runner would not ask, and it is refused rather than
    // left unasked.
    private static func encoded(_ encoded: Encoded, expecting held: Name, _ expected: Value, in written: Value.Dictionary) throws -> Asked {
        try reads(written, ["bytes", "text"], about: "an encoding")

        // The binary encoding is canonical, so bytes that read as a value
        // write back as themselves, and a case about them says so.
        if case .binary = encoded, held == "reads" {
            throw ConformanceError("the binary encoding is canonical, so a case that reads bytes expects `spells`")
        }

        let reading = try reading(held, expected)

        // `reads` says as well that this is not the writer's layout, or the
        // case would be `spells` and ask the writer too. A case is held to
        // that where it is read, since it is the case that is wrong then.
        if case let .reads(expected) = reading, (try? encoded.written(expected)) == encoded.data {
            throw ConformanceError("a text in the writer's layout expects `spells`, and this one says `reads`")
        }

        return .encoded(encoded, reading)
    }

    // What an encoding expects. Refused where it is read, which is the one
    // stage it reaches, so no other stage may be written beside it.
    private static func reading(_ held: Name, _ expected: Value) throws -> Reading {
        switch held {
        case "reads":
            return .reads(expected)

        case "spells":
            return .spells(expected)

        case "refuses":
            guard try stage(expected) == .load else {
                throw ConformanceError("bytes and text are refused where they are read, and not at \(expected)")
            }

            return .refuses

        case "answers":
            throw ConformanceError("bytes and text do not run, so they answer nothing")

        default:
            throw ConformanceError("a case expects what its bytes or text read as, what they spell, or that they are refused, and not `\(held)`")
        }
    }

    private static func supplied(in written: Value?) throws -> Vocabulary? {
        guard let written else { return nil }

        guard case let .dictionary(module) = written else {
            throw ConformanceError("the vocabulary a case asks for is a module")
        }

        let entries: Value.Dictionary

        switch module["procedures"] {
        case nil:
            entries = Value.Dictionary([:])

        case let .dictionary(declared)?:
            entries = declared

        case let other?:
            throw ConformanceError("the vocabulary a case asks for declares its procedures as a mapping, and not as \(other)")
        }

        if let taken = try module.named().map(\.name).first(where: { name in !Vocabulary.declaringKeys.contains(name) }) {
            throw ConformanceError(
                "the vocabulary a case asks for writes '\(taken)'. A vocabulary writes `imports`"
                    + " and declares `types`, `contracts`, `extensions` and `procedures`, and how it is"
                    + " read is the runner's"
            )
        }

        let procedures: [Supplied] = try entries.named().map { entry in try Self.supplied(entry.name, entry.value) }

        // The module as the reader takes it: what the case wrote, with the
        // declarations stripped of the keys that are the host's rather than the
        // document's, and the version the runner says for itself. A member is
        // one of the host's procedures, written where its type is given it.
        var stripped = Dictionary(uniqueKeysWithValues: try module.named().map { field in (field.name, field.value) })
        var members: [Supplied] = []

        for table in ["types", "extensions"] as [Name] {
            guard case let .dictionary(given)? = module[table] else { continue }

            var rewritten: [Name: Value] = [:]

            for (type, written) in try given.named() {
                guard case let .dictionary(fields) = written, case let .dictionary(declared)? = fields["procedures"] else {
                    rewritten[type] = written

                    continue
                }

                let supplied = try declared.named().map { member in
                    (member.name, try Self.supplied(try Name("\(type).\(member.name)"), member.value))
                }

                members += supplied.map(\.1)
                rewritten[type] = .dictionary(
                    fields.writing(
                        "procedures",
                        with: .dictionary(Value.Dictionary(Dictionary(uniqueKeysWithValues: supplied.map { name, one in (name, one.declaration) })))
                    )
                )
            }

            stripped[table] = .dictionary(Value.Dictionary(rewritten))
        }

        stripped["warp"] = .int(1)
        stripped["procedures"] = procedures.isEmpty
            ? nil
            : .dictionary(Dictionary(uniqueKeysWithValues: procedures.map { one in (one.name, one.declaration) }))

        return Vocabulary(module: .dictionary(Value.Dictionary(stripped)), procedures: procedures + members)
    }

    // One of the host's procedures as a vocabulary writes it: the declaration,
    // and beside it what the host's implementation does.
    private static func supplied(_ name: Name, _ written: Value) throws -> Supplied {
        guard case let .dictionary(mapping) = written else {
            throw ConformanceError("'\(name)' is written the way a procedure is")
        }

        let declaration = Value.dictionary(
            Dictionary(
                uniqueKeysWithValues: try mapping.named()
                    .filter { field in !Supplied.ownKeys.contains(field.name) }
                    .map { field in (field.name, field.value) }
            )
        )

        return Supplied(
            name: name,
            declaration: declaration,
            answers: mapping["answers"] ?? .null,
            runs: try Self.flag(mapping, "runs", of: name, or: false),
            isolated: try Self.flag(mapping, "isolated", of: name, or: true),
            failing: try Self.failing(mapping["failing"], of: name)
        )
    }

    // What the entry is given is a mapping or is not written. Anything else
    // is refused rather than read as nothing given: a case that wrote
    // `arguments 1` asked a question no runner can answer the same way.
    private static func given(_ written: Value?, of name: String) throws -> [Name: Value] {
        switch written {
        case nil:
            return [:]

        case let .dictionary(given)?:
            return Dictionary(uniqueKeysWithValues: try given.named().map { entry in (entry.name, entry.value) })

        case let other?:
            throw ConformanceError("'\(name)' writes `arguments` as \(other), and it is a mapping or is not written")
        }
    }

    // A key the runner reads beside a declaration is a bool or is not written.
    // Anything else is refused rather than read as one of the two: a case that
    // wrote `runs 1` asked a question no runner can answer the same way.
    private static func flag(_ mapping: Value.Dictionary, _ key: Name, of procedure: Name, or absent: Bool) throws -> Bool {
        switch mapping[key] {
        case nil: return absent
        case let .bool(flag)?: return flag
        case let other?:
            throw ConformanceError("'\(procedure)' writes `\(key)` as \(other), and it is a Bool or is not written")
        }
    }

    private static func failing(_ written: Value?, of procedure: Name) throws -> [String] {
        guard let written else { return [] }

        guard case let .array(named) = written else {
            throw ConformanceError("'\(procedure)' writes `failing` as \(written), and it is an array of names")
        }

        return try named.map { held in
            guard case let .string(type) = held else {
                throw ConformanceError("'\(procedure)' fails with \(held), and what it fails with is named")
            }

            return type
        }
    }
}

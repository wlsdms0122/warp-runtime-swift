//
//  ConformanceTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// The specification's cases, run against this implementation.
//
// Every other test here reaches inside — `@testable`, private types, internal
// helpers — which is right for a test about how something is built. These are
// about something else: whether this is the language `spec/` describes. So this
// file imports what any caller imports and nothing more. A runner that could see
// inside could pass by agreeing with the implementation rather than with the
// specification, which is the one thing it must not be able to do.
//
// The cases are data, and the point of that is that this file is replaceable.
// An implementation in another language writes its own runner — this much code —
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
            let reached = await reached(sut)

            #expect(reached == stage, "\(sut.name): \(sut.note)")
        }
    }

    @Test("the cases are the specification's, and it has some")
    func thereAreCases() throws {
        // Given — a suite that silently found nothing would pass, and passing by
        // asking nothing is the failure mode a conformance suite has
        let sut = try Case.all()

        #expect(sut.count >= 10)
        #expect(Set(sut.map(\.name)).count == sut.count)
    }

    // MARK: - Public
    // MARK: - Private
    private func run(_ sut: Case) async throws -> Value {
        let linker = Linker()
        let module = try Loader().load(sut.program, identity: nil)
        let image = try linker.link([module] + Module.standard, entry: "entry")

        return try await Executor().run(image, arguments: sut.arguments)
    }

    // How far a case got before it was refused. The stage is part of the answer:
    // stopping at a run what another implementation stops at a link means
    // something already happened, and what already happened cannot be taken back.
    private func reached(_ sut: Case) async -> Case.Stage? {
        let linker = Linker()
        let module: Module

        do {
            module = try Loader().load(sut.program, identity: nil)
        } catch {
            return .load
        }

        let image: Image

        do {
            image = try linker.link([module] + Module.standard, entry: "entry")
        } catch {
            return .link
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
// A case is not a program and is not written in the shape of one. It is spelled
// in the same text — the encoding carries a tree and never learns what a tree
// means, so there is one of those and not two — but what it holds under `test`
// is a test, and the document it asks about is nested whole under `program`.
//
// Which is what lets the two be told apart by saying so rather than by noticing:
// a case declares `test`, a document declares `warp`, and each is refused by the
// other's reader for what it is instead of for the keys it happens to carry.
struct Case: Sendable, CustomStringConvertible {
    // Which shapes a runner has to understand to ask these questions. It moves
    // for the same reason `warp` does and on its own schedule — the day a case
    // may say something new is not the day a document may.
    static let version = 1
    static let earliest = 1

    static let versionKey: Name = "test"

    enum Stage: String, Sendable {
        case load
        case link
        case run
    }

    enum Expectation: Sendable {
        case answers(Value)
        case refuses(Stage)
    }

    // MARK: - Property
    let name: String
    let note: String
    let program: Value
    let arguments: [Name: Value]
    let expectation: Expectation

    var description: String { name }

    // MARK: - Initializer
    init(from written: Value) throws {
        // The version first, and before the shape, for the reason a document
        // reads its own first: a later case may say something this runner has
        // no name for, and "I am too old for this" is a different answer from
        // "this is not a case".
        guard let declared = written[Self.versionKey] else {
            throw ConformanceError(
                "this is not a case — it does not say which test it is written for"
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
            self.arguments = Swift.Dictionary(
                uniqueKeysWithValues: arguments.entries.map { entry in (entry.name, entry.value) }
            )
        } else {
            self.arguments = [:]
        }

        // One of `answers` or `refuses`, and exactly one. The slot groups them so
        // that this is a question about one record instead of a rule about two
        // sibling keys — but a record is not a choice, so the count is still
        // counted here. A case edited from one to the other and left holding both
        // would otherwise start asking a different question than it reads as, and
        // nobody would be told.
        guard
            case let .dictionary(expect)? = written["expect"],
            expect.count == 1,
            let (held, expected) = expect.entries.first
        else {
            throw ConformanceError("a case expects exactly one of `answers` or `refuses`")
        }

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
    // The cases live beside the specification they belong to rather than inside
    // this package, because they are not this implementation's — the day there
    // is a second implementation they move with `spec/` and this file stays.
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
        // folder is somebody else's business — a `.DS_Store`, a `.orig` left by
        // a merge, a copy someone kept while editing. A runner that refused to
        // start over any of those would be putting "is this folder tidy" and "is
        // this implementation the language" behind one red light, and the second
        // question is the only one it was built to ask.
        //
        // The cost is real and is accepted: a case saved under a name this misses
        // is not asked, and nothing here says so. What catches that is the same
        // thing that catches a case deleted outright — it is a file in a diff,
        // and the dumper that writes these names them.
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { file in file.lastPathComponent.hasSuffix(".test.warpt") }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }

        return try files.map { file in
            try Case(from: try TextEncoding.value(from: try Data(contentsOf: file)))
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

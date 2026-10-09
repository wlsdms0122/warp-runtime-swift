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
import WarpStandard

// The specification's cases, run against this implementation: whether this is
// the language `spec/` describes. So this file imports what any host imports
// and nothing more. A runner that could see inside could pass by agreeing with
// the implementation rather than with the specification.
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
        switch sut.asked {
        case let .program(program):
            switch program.expectation {
            case let .answers(expected):
                let answered = try await run(program)

                #expect(answered == expected, "\(sut.name): \(sut.note)")

            case let .refuses(stage):
                let reached = try await reached(program)

                #expect(reached == stage, "\(sut.name): \(sut.note)")

            case let .builds(expected):
                let built = try await built(program)

                #expect(built == expected, "\(sut.name): \(sut.note)")
            }

        case let .object(object):
            switch object.expectation {
            case let .answers(expected):
                let answered = try await run(object)

                #expect(answered == expected, "\(sut.name): \(sut.note)")

            case let .refuses(stage):
                let reached = try await reached(object)

                #expect(reached == stage, "\(sut.name): \(sut.note)")
            }

        case let .encoded(encoded, reading):
            switch reading {
            case let .reads(expected):
                #expect(try encoded.read() == expected, "\(sut.name): \(sut.note)")

            case let .spells(expected):
                #expect(try encoded.read() == expected, "\(sut.name): \(sut.note)")
                #expect(try encoded.written(expected) == encoded.data, "\(sut.name): \(sut.note)")

            case .refuses:
                #expect(throws: (any Error).self, "\(sut.name): \(sut.note)") { try encoded.read() }
            }
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
    // How far a case got before it was refused. The stage is part of the answer:
    // stopping at a run what another implementation stops at a build means
    // something already happened, and what already happened cannot be taken back.
    func reached(_ sut: Case.Program) async throws -> Case.Stage? {
        let builder = Builder()
        let vocabulary = try await sut.brought
        let module: Module

        // The case's own document is read apart from the rest, because a
        // document that does not read is the answer to this question and a
        // vocabulary that does not read is a case nobody can ask.
        do {
            module = try Loader().load(sut.document, identity: try Identity.of(sut.document))
        } catch {
            return .load
        }

        let image: Image

        do {
            let supplying = try Supplying(vocabulary + sut.beside + [module] + Module.standard)
            let laid = try await laid(sut, with: builder, supplying: supplying)
            let own = try await builder.compile([module], against: laid, supplying: supplying)

            image = try builder.link(laid + own, supplying: supplying)
        } catch {
            return .build
        }

        do {
            _ = try await Executor().run(image, entry: "entry", arguments: sut.arguments)
        } catch {
            return try refused(error)
        }

        return nil
    }

    // MARK: - Private
    // A run that stopped. A refusal is the run's, and a failure that escaped
    // the entry is a failure, which is not a refusal and matches no
    // expectation: a case measuring one catches it with `attempt` and answers
    // what the rescue saw.
    private func refused(_ error: any Error) throws -> Case.Stage {
        if let failure = error as? any RecoverableFailure {
            throw ConformanceError("a failure escaped the entry: \(failure.type): \(failure.message)")
        }

        return .run
    }

    private func run(_ sut: Case.Program) async throws -> Value {
        let builder = Builder()
        let supplying = try await Supplying(sut.modules())
        let laid = try await laid(sut, with: builder, supplying: supplying)
        let own = try await builder.compile(
            [try Loader().load(sut.document, identity: try Identity.of(sut.document))],
            against: laid,
            supplying: supplying
        )
        let image = try builder.link(laid + own, supplying: supplying)

        return try await Executor().run(image, entry: "entry", arguments: sut.arguments)
    }

    // What stands before the case's own document: the vocabulary the case
    // asked for and the standard one, then the documents beside the program
    // laid one after another in the order written, each against what stands
    // before it, the way a host lays documents as they arrive.
    private func laid(_ sut: Case.Program, with builder: Builder, supplying: Supplying) async throws -> [Compiled] {
        var laid = try await builder.compile(try await sut.brought + Module.standard, against: [], supplying: supplying)

        for document in sut.beside {
            laid += try await builder.compile([document], against: laid, supplying: supplying)
        }

        return laid
    }

    // The object the program's own document compiles to, against what the
    // case asked the runner to bring and the standard vocabulary. Every
    // object is keyed under the digest of its bytes and every document under
    // the digest of its own, under *what a runner does* in `spec/conformance.md`.
    private func built(_ sut: Case.Program) async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try await Supplying(sut.modules())
        let behind = try await laid(sut, with: builder, supplying: supplying)
        let own = try await builder.compile(
            [try Loader().load(sut.document, identity: try Identity.of(sut.document))],
            against: behind,
            supplying: supplying
        )

        guard own.count == 1 else { throw ConformanceError("\(own.count) documents compiled where one stood") }

        return try own[0].object()
    }

    // An object read under the identity it writes, laid beside the standard
    // vocabulary compiled the way a `builds` case sees it, and run.
    private func run(_ sut: Case.Object) async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try Supplying(Module.standard)
        let behind = try await builder.compile(Module.standard, against: [], supplying: supplying)
        let read = try Compiled(written: sut.written, of: sut.identity)
        let image = try builder.link(behind + [read], supplying: supplying)

        return try await Executor().run(image, entry: "entry", arguments: sut.arguments)
    }

    private func reached(_ sut: Case.Object) async throws -> Case.Stage? {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try Supplying(Module.standard)
        let behind = try await builder.compile(Module.standard, against: [], supplying: supplying)
        let read: Compiled

        do {
            read = try Compiled(written: sut.written, of: sut.identity)
        } catch {
            return .load
        }

        let image: Image

        do {
            image = try builder.link(behind + [read], supplying: supplying)
        } catch {
            return .build
        }

        do {
            _ = try await Executor().run(image, entry: "entry", arguments: sut.arguments)
        } catch {
            return try refused(error)
        }

        return nil
    }
}

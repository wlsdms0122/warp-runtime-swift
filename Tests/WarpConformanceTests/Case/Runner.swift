//
//  Runner.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/22/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

// What a runner does with a case, under *what a runner does* in
// `spec/conformance.md`. So this file imports what any host imports and
// nothing more. A runner that could see inside could pass by agreeing with the
// implementation rather than with the specification.
//
// The cases are data, and the point of that is that this file is replaceable.
// An implementation in another language writes its own runner (this much code)
// and asks the same questions.
struct Runner {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // How far a case got before it was refused. The stage is part of the answer:
    // stopping at a run what another implementation stops at a build means
    // something already happened, and what already happened cannot be taken back.
    func reached(_ program: Case.Program) async throws -> Refusal? {
        let builder = Builder()
        let vocabulary = try await program.brought
        let module: Module

        // The case's own document is read apart from the rest, because a
        // document that does not read is the answer to this question and a
        // vocabulary that does not read is a case nobody can ask.
        do {
            module = try Loader().load(program.document, identity: try Identity.of(program.document))
        } catch {
            return Refusal(stage: .load, error: error)
        }

        let image: Image

        do {
            let supplying = try Supplying(vocabulary + program.beside + [module] + Module.standard)
            let laid = try await laid(program, with: builder, supplying: supplying)
            let own = try await builder.compile([module], against: laid, supplying: supplying)

            image = try builder.link(laid + own, supplying: supplying)
        } catch {
            return Refusal(stage: .build, error: error)
        }

        do {
            _ = try await Executor().run(image, entry: "entry", arguments: program.arguments)
        } catch {
            return try refused(error)
        }

        return nil
    }

    func run(_ program: Case.Program) async throws -> Value {
        let builder = Builder()
        let supplying = try await Supplying(program.modules())
        let laid = try await laid(program, with: builder, supplying: supplying)
        let own = try await builder.compile(
            [try Loader().load(program.document, identity: try Identity.of(program.document))],
            against: laid,
            supplying: supplying
        )
        let image = try builder.link(laid + own, supplying: supplying)

        return try await Executor().run(image, entry: "entry", arguments: program.arguments)
    }

    // The program run from objects: every document compiled is written to
    // bytes and read back, and the link is built from what was read.
    func roundTrip(_ program: Case.Program) async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try await Supplying(program.modules())
        var behind = try await builder.compile(try await program.brought + Module.standard, against: [], supplying: supplying)

        // A document beside the program is read back with the fingerprint
        // it was compiled to, since the host hands that in and a document
        // leaning on it cannot be linked without it.
        for document in program.beside {
            let compiled = try await builder.compile([document], against: behind, supplying: supplying)
            let written = try compiled[0].object()
            let read = try Compiled(
                written: try BinaryEncoding().value(from: try BinaryEncoding().data(from: written)),
                of: document.identity,
                fingerprint: compiled[0].fingerprint
            )

            guard try read.object() == written else { throw ConformanceError("an object beside the program writes back otherwise") }

            behind += [read]
        }

        let identity = try Identity.of(program.document)
        let own = try await builder.compile(
            [try Loader().load(program.document, identity: identity)],
            against: behind,
            supplying: supplying
        )
        let object = try own[0].object()
        let back = try BinaryEncoding().value(from: try BinaryEncoding().data(from: object))

        // A case carries an object as data in a text, so the object is also
        // asked to travel inside one.
        let carried: Value = [
            "test": 1,
            "name": "round-trip",
            "note": "round-trip",
            "object": object,
            "expect": ["answers": .null]
        ]
        let carriedBack = try TextEncoding().value(from: try TextEncoding().data(from: carried))

        guard back == object, carriedBack == carried else { throw ConformanceError("an object reads back otherwise") }

        let read = try Compiled(written: back, of: identity)

        guard try read.object() == object else { throw ConformanceError("an object read back writes otherwise") }

        let image = try builder.link(behind + [read], supplying: supplying)

        return try await Executor().run(image, entry: "entry", arguments: program.arguments)
    }

    // The object the program's own document compiles to, against what the
    // case asked the runner to bring and the standard vocabulary. Every
    // object is keyed under the digest of its bytes and every document under
    // the digest of its own, under *what a runner does* in `spec/conformance.md`.
    func built(_ program: Case.Program) async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try await Supplying(program.modules())
        let behind = try await laid(program, with: builder, supplying: supplying)
        let own = try await builder.compile(
            [try Loader().load(program.document, identity: try Identity.of(program.document))],
            against: behind,
            supplying: supplying
        )

        guard own.count == 1 else { throw ConformanceError("\(own.count) documents compiled where one stood") }

        return try own[0].object()
    }

    func reached(_ object: Case.Object) async throws -> Refusal? {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try Supplying(Module.standard)
        let behind = try await builder.compile(Module.standard, against: [], supplying: supplying)
        let read: Compiled

        do {
            read = try Compiled(written: object.written, of: object.identity)
        } catch {
            return Refusal(stage: .load, error: error)
        }

        let image: Image

        do {
            image = try builder.link(behind + [read], supplying: supplying)
        } catch {
            return Refusal(stage: .build, error: error)
        }

        do {
            _ = try await Executor().run(image, entry: "entry", arguments: object.arguments)
        } catch {
            return try refused(error)
        }

        return nil
    }

    // An object read under the identity it writes, laid beside the standard
    // vocabulary compiled the way a `builds` case sees it, and run.
    func run(_ object: Case.Object) async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try Supplying(Module.standard)
        let behind = try await builder.compile(Module.standard, against: [], supplying: supplying)
        let read = try Compiled(written: object.written, of: object.identity)
        let image = try builder.link(behind + [read], supplying: supplying)

        return try await Executor().run(image, entry: "entry", arguments: object.arguments)
    }

    // MARK: - Private
    // A run that stopped. A refusal is the run's, and a failure that escaped
    // the entry is a failure, which is not a refusal and matches no
    // expectation: a case measuring one catches it with `attempt` and answers
    // what the rescue saw.
    private func refused(_ error: any Error) throws -> Refusal {
        if let failure = error as? any RecoverableFailure {
            throw ConformanceError("a failure escaped the entry: \(failure.type): \(failure.message)")
        }

        return Refusal(stage: .run, error: error)
    }

    // What stands before the case's own document: the vocabulary the case
    // asked for and the standard one, then the documents beside the program
    // laid one after another in the order written, each against what stands
    // before it, the way a host lays documents as they arrive.
    private func laid(_ program: Case.Program, with builder: Builder, supplying: Supplying) async throws -> [Compiled] {
        var laid = try await builder.compile(try await program.brought + Module.standard, against: [], supplying: supplying)

        for document in program.beside {
            laid += try await builder.compile([document], against: laid, supplying: supplying)
        }

        return laid
    }
}

//
//  Run.swift
//  warpx
//

import Foundation
import Warp
import WarpStandard
import WarpSyntax

// One program: its documents, the entry the caller names, what it is given
// and the store its host effects reach.
struct Run {
    // MARK: - Property
    let files: [URL]
    let entry: Name
    let arguments: [Name: Value]
    let store: Store
    let together: Bool

    // MARK: - Initializer
    // MARK: - Public
    // Built from the documents as they are; a refusal says the stage it
    // came from.
    func straight() async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let vocabulary = Module.standard + [try Module.host()]
        let supplying = try Supplying(vocabulary)
        var laid = try await builder.compile(vocabulary, against: [], supplying: supplying)
        let batches: [[Module]]

        do {
            batches = try self.batches()
        } catch {
            throw Refusal(stage: .load, error: error)
        }

        let image: Image

        do {
            for batch in batches {
                laid += try await builder.compile(batch, against: laid, supplying: supplying)
            }

            image = try builder.link(laid, supplying: supplying)
        } catch {
            throw Refusal(stage: .build, error: error)
        }

        do {
            return try await run(image)
        } catch {
            throw Refusal(stage: .run, error: error)
        }
    }

    // Built from the documents' objects: each is written to bytes and read
    // back, then linked beside the vocabulary compiled fresh.
    func throughObjects() async throws -> Value {
        let builder = Builder(fingerprinting: Fingerprint.of)
        let vocabulary = Module.standard + [try Module.host()]
        let supplying = try Supplying(vocabulary)
        var laid = try await builder.compile(vocabulary, against: [], supplying: supplying)

        for batch in try batches() {
            let compiled = try await builder.compile(batch, against: laid, supplying: supplying)

            guard compiled.count == batch.count else {
                throw RunError("\(compiled.count) documents compiled where \(batch.count) stood")
            }

            for own in compiled {
                let object = try own.object()
                let bytes = try BinaryEncoding().data(from: object)
                let read = try Compiled(written: try BinaryEncoding().value(from: bytes), of: own.identity, fingerprint: try Fingerprint.of(object))

                laid.append(read)
            }
        }

        return try await run(builder.link(laid, supplying: supplying))
    }

    // MARK: - Private
    // One batch holding every document, or one batch per document in the
    // order given.
    private func batches() throws -> [[Module]] {
        let modules = try modules()

        return together ? [modules] : modules.map { [$0] }
    }

    private func modules() throws -> [Module] {
        try files.map { file in
            let written = try TextEncoding().value(from: try String(contentsOf: file, encoding: .utf8))

            return try Loader().load(written)
        }
    }

    private func run(_ image: Image) async throws -> Value {
        try await Executor(environment: store).run(image, entry: entry, arguments: arguments)
    }
}

//
//  Workload.swift
//  WarpBench
//
//  Created by JSilver on 9/2/26.
//

import Foundation
import Warp
import WarpSyntax
import WarpStandard

// One program from `program/`, linked once and run as many times as asked.
//
// Every act a caller pays for is timed apart. `load()` is what the text costs
// to become a module, `build()` what that module costs to become an image, and
// `time(rounds:)` what running the image costs. A document arrives while the
// program is running, so the first two are run time too: work moved out of the
// run and into the build shows as a gain on one figure and a loss on the other,
// and a document that runs once pays all three.
struct Workload {
    // MARK: - Property
    let name: String

    // The document as it arrives, kept so that arriving can be timed. A host
    // is handed text and reads a module out of it, and that reading is work
    // no other figure here carries.
    private let text: String

    private let module: Module
    private let image: Image

    // Where every program starts: a public procedure taking the number of
    // rounds to run, by the one name every document under `program/` gives it.
    private static let entry: Name = "entry"

    // MARK: - Initializer
    init(reading url: URL) async throws {
        let text = try String(contentsOf: url, encoding: .utf8)

        self.name = url.deletingPathExtension().lastPathComponent
        self.text = text
        self.module = try Loader().load(try TextEncoding().value(from: text), identity: nil)
        self.image = try await Self.built(module)
    }

    // MARK: - Public
    // How long one run of `rounds` rounds takes. The program answers something it
    // computed so that no round can be skipped.
    func time(rounds: Int) async throws -> Duration {
        try await elapsed { _ = try await Executor().run(image, entry: Self.entry, arguments: ["rounds": .int(rounds)]) }
    }

    // How long this document costs to arrive: its text read as a value, and
    // that value read as a module. Nothing can be linked until this is paid,
    // and a caller that is handed documents often pays it every time.
    func load() throws -> Duration {
        try elapsed { _ = try Loader().load(try TextEncoding().value(from: text), identity: nil) }
    }

    // How long one build of this module takes.
    func build() async throws -> Duration {
        try await elapsed { _ = try await Self.built(module) }
    }

    // The same build where the vocabulary was compiled and laid down already,
    // which is what a caller building many documents against one vocabulary
    // pays.
    func baked() async throws -> Duration {
        let vocabulary = try await Vocabulary.standard.value

        return try await elapsed {
            let builder = Builder()

            _ = try builder.link(
                vocabulary.laid.compiled + (try await builder.compile([module], against: vocabulary.laid)),
                supplying: vocabulary.brought
            )
        }
    }

    // How long a module that builds, runs one round and is dropped takes. The
    // two halves of the same measurement, timed together rather than added, so
    // nothing between them is left out. What arriving costs is `load()`.
    func once() async throws -> Duration {
        try await elapsed {
            _ = try await Executor().run(
                try await Self.built(module),
                entry: Self.entry,
                arguments: ["rounds": .int(1)]
            )
        }
    }

    // MARK: - Private
    private static func built(_ module: Module) async throws -> Image {
        try await Builder().build([module] + Module.standard)
    }
}

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
// Both halves are timed. `time(rounds:)` is the cost of running an image the
// way a caller runs one, and `link()` is the cost of making that image. A
// document arrives while the program is running, so the link is run time too:
// work moved out of the run and into the link shows as a gain on one figure
// and a loss on the other, and a document that runs once pays both.
struct Workload {
    // MARK: - Property
    let name: String

    private let module: Module
    private let image: Image

    // MARK: - Initializer
    init(reading url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)

        self.name = url.deletingPathExtension().lastPathComponent
        self.module = try Loader().load(try TextEncoding.value(from: text), identity: nil)
        self.image = try Self.linked(module)
    }

    // MARK: - Public
    // How long one run of `rounds` rounds takes. The program answers something it
    // computed so that no round can be skipped.
    func time(rounds: Int) async throws -> Duration {
        try await elapsed { _ = try await Executor().run(image, arguments: ["rounds": .int(rounds)]) }
    }

    // How long one link of this module takes.
    func link() throws -> Duration {
        try elapsed { _ = try Self.linked(module) }
    }

    // The same link where the vocabulary was compiled once already, which is
    // what a caller linking many documents against one vocabulary pays.
    func baked() throws -> Duration {
        try elapsed {
            let linker = Linker()

            _ = try linker.link(
                Self.vocabulary + (try linker.compile([module], against: Self.vocabulary, supplying: Self.brought)),
                entry: "entry",
                supplying: Self.brought
            )
        }
    }

    // How long a document that arrives, links, runs one round and is dropped
    // takes. The two halves of the same measurement, timed together rather
    // than added, so nothing between them is left out.
    func once() async throws -> Duration {
        try await elapsed {
            _ = try await Executor().run(try Self.linked(module), arguments: ["rounds": .int(1)])
        }
    }

    // MARK: - Private
    // The standard vocabulary compiled once, the way a host that brings it
    // compiles it once.
    private static let vocabulary = try! Linker().compile(Module.standard)

    // The native code behind that vocabulary, joined up once, the way a host
    // that brings the same words every run holds them.
    private static let brought = Supplying(Module.standard)

    private static func linked(_ module: Module) throws -> Image {
        try Linker().link([module] + Module.standard, entry: "entry")
    }
}

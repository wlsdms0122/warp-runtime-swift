//
//  Workload.swift
//  WarpBench
//
//  Created by JSilver on 9/2/26.
//

import Foundation
import Warp
import WarpSyntax

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
    // Seconds one run of `rounds` rounds takes. The program answers something it
    // computed so that no round can be skipped.
    func time(rounds: Int) async throws -> Duration {
        let clock = ContinuousClock()
        let started = clock.now

        _ = try await Executor().run(image, arguments: ["rounds": .int(rounds)])

        return clock.now - started
    }

    // Seconds one link of this module takes.
    func link() throws -> Duration {
        let clock = ContinuousClock()
        let started = clock.now

        _ = try Self.linked(module)

        return clock.now - started
    }

    // Seconds a document that arrives, links, runs one round and is dropped
    // takes. The two halves of the same measurement, timed together rather
    // than added, so nothing between them is left out.
    func once() async throws -> Duration {
        let clock = ContinuousClock()
        let started = clock.now

        _ = try await Executor().run(try Self.linked(module), arguments: ["rounds": .int(1)])

        return clock.now - started
    }

    // MARK: - Private
    private static func linked(_ module: Module) throws -> Image {
        try Linker().link([module] + Module.standard, entry: "entry")
    }
}

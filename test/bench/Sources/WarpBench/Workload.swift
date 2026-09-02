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
// What is timed is `Executor.run` and nothing before it. Reading, loading and
// linking happen in the initializer, so a measurement is the cost of running an
// image the way a caller runs one.
struct Workload {
    // MARK: - Property
    let name: String

    private let image: Image

    // MARK: - Initializer
    init(reading url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let module = try Loader().load(try TextEncoding.value(from: text), identity: nil)

        self.name = url.deletingPathExtension().lastPathComponent
        self.image = try Linker().link(
            [module] + Module.standard,
            entry: Draft.qualified("entry", in: module.namespace)
        )
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

    // MARK: - Private
}

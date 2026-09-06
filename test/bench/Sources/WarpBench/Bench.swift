//
//  Bench.swift
//  WarpBench
//
//  Created by JSilver on 9/2/26.
//

import Foundation

// Runs every program under `program/` and prints one table: nanoseconds per
// round and how that compares to the loop alone, beside the cost of linking
// the same program and the cost of a document that arrives, links, runs one
// round and is dropped.
//
// Usage: `WarpBench [rounds] [repeats]`. Rounds default to a million, repeats
// to three; the reported figure is the fastest repeat. Every program is warmed
// up once before it is timed.
//
// The fastest rather than the middle one: nothing else on the machine can make
// a run faster, so the fastest sample is the one least mixed with whatever else
// was running, and two builds compare on the same footing.
@main
struct Bench {
    // MARK: - Property
    private static let defaultRounds = 1_000_000
    private static let defaultRepeats = 3
    private static let warmupRounds = 1_000

    // A link and a single round are one measurement each rather than a rate,
    // so they are sampled many times and the fastest reported.
    private static let linkSamples = 201
    private static let baseline = "loop"

    // MARK: - Initializer
    // MARK: - Public
    static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        let rounds = arguments.first.flatMap(Int.init) ?? defaultRounds
        let repeats = arguments.dropFirst().first.flatMap(Int.init) ?? defaultRepeats
        let workloads = try Self.workloads()

        var measured: [String: Measurement] = [:]

        for workload in workloads {
            _ = try await workload.time(rounds: warmupRounds)

            var samples: [Duration] = []

            for _ in 0 ..< repeats {
                samples.append(try await workload.time(rounds: rounds))
            }

            var links: [Duration] = []
            var onces: [Duration] = []

            for _ in 0 ..< linkSamples {
                links.append(try workload.link())
                onces.append(try await workload.once())
            }

            measured[workload.name] = Measurement(
                perRound: Self.nanoseconds(Self.fastest(samples)) / Double(rounds),
                link: Self.nanoseconds(Self.fastest(links)),
                once: Self.nanoseconds(Self.fastest(onces))
            )
        }

        print(Self.table(measured, rounds: rounds, repeats: repeats))
    }

    // MARK: - Private
    private struct Measurement {
        let perRound: Double
        let link: Double
        let once: Double
    }

    private static func workloads() throws -> [Workload] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("program")
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "warpt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try files.map(Workload.init(reading:))
    }

    private static func fastest(_ samples: [Duration]) -> Duration {
        samples.min() ?? .zero
    }

    private static func nanoseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1e9
            + Double(duration.components.attoseconds) / 1e9
    }

    private static func table(_ measured: [String: Measurement], rounds: Int, repeats: Int) -> String {
        let loop = measured[baseline]?.perRound ?? 0
        var lines = [
            "rounds \(rounds), fastest of \(repeats); link and once are the fastest of \(linkSamples)",
            "",
            "| workload | ns/round | minus loop | x loop | link us | once us |",
            "|---|---|---|---|---|---|"
        ]

        for (name, measurement) in measured.sorted(by: { $0.key < $1.key }) {
            let over = measurement.perRound - loop
            let ratio = loop > 0 ? measurement.perRound / loop : 0

            lines.append(String(
                format: "| %@ | %.0f | %.0f | %.2f | %.0f | %.0f |",
                name, measurement.perRound, over, ratio,
                measurement.link / 1000, measurement.once / 1000
            ))
        }

        return lines.joined(separator: "\n")
    }
}

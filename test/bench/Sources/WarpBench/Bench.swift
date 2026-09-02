//
//  Bench.swift
//  WarpBench
//
//  Created by JSilver on 9/2/26.
//

import Foundation

// Runs every program under `program/` for a number of rounds and prints one
// table: nanoseconds per round, and how that compares to the loop alone.
//
// Usage: `WarpBench [rounds] [repeats]`. Rounds default to a million, repeats
// to three; the reported figure is the median repeat. Every program is warmed
// up once before it is timed.
@main
struct Bench {
    // MARK: - Property
    private static let defaultRounds = 1_000_000
    private static let defaultRepeats = 3
    private static let warmupRounds = 1_000
    private static let baseline = "loop"

    // MARK: - Initializer
    // MARK: - Public
    static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        let rounds = arguments.first.flatMap(Int.init) ?? defaultRounds
        let repeats = arguments.dropFirst().first.flatMap(Int.init) ?? defaultRepeats
        let workloads = try Self.workloads()

        var perRound: [String: Double] = [:]

        for workload in workloads {
            _ = try await workload.time(rounds: warmupRounds)

            var samples: [Duration] = []

            for _ in 0 ..< repeats {
                samples.append(try await workload.time(rounds: rounds))
            }

            let median = samples.sorted()[samples.count / 2]
            let seconds = Double(median.components.seconds)
                + Double(median.components.attoseconds) / 1e18

            perRound[workload.name] = seconds * 1e9 / Double(rounds)
        }

        print(Self.table(perRound, rounds: rounds, repeats: repeats))
    }

    // MARK: - Private
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

    private static func table(_ perRound: [String: Double], rounds: Int, repeats: Int) -> String {
        let loop = perRound[baseline] ?? 0
        var lines = [
            "rounds \(rounds), median of \(repeats)",
            "",
            "| workload | ns/round | minus loop | x loop |",
            "|---|---|---|---|"
        ]

        for (name, nanoseconds) in perRound.sorted(by: { $0.key < $1.key }) {
            let over = nanoseconds - loop
            let ratio = loop > 0 ? nanoseconds / loop : 0

            lines.append(String(
                format: "| %@ | %.0f | %.0f | %.2f |",
                name, nanoseconds, over, ratio
            ))
        }

        return lines.joined(separator: "\n")
    }
}

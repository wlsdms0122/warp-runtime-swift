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
// Usage: `WarpBench [rounds] [repeats] [--against <table>]`. Rounds default to
// a million, repeats to three; the reported figure is the fastest repeat. Every
// program is warmed up once before it is timed.
//
// `--against` reads a table this printed earlier and reports how far each
// figure moved instead of the figures alone, so comparing two builds is one
// reading rather than two and the arithmetic is not the reader's.
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
        let arguments = Array(CommandLine.arguments.dropFirst())
        let numbers = arguments.prefix { argument in Int(argument) != nil }
        let rounds = numbers.first.flatMap(Int.init) ?? defaultRounds
        let repeats = numbers.dropFirst().first.flatMap(Int.init) ?? defaultRepeats
        let against = arguments.firstIndex(of: "--against").map { at in arguments[at + 1] }
        let baseline = try against.map(Self.reading)
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

        print(Self.table(measured, against: baseline, from: against, rounds: rounds, repeats: repeats))
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

    // A table this printed earlier, read back by workload. Only the two
    // figures a comparison moves are taken; the rest are worked out again.
    private static func reading(_ path: String) throws -> [String: Measurement] {
        var read: [String: Measurement] = [:]

        for line in try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n") {
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { cell in cell.trimmingCharacters(in: .whitespaces) }

            guard cells.count >= 7, let perRound = Double(cells[2]), let link = Double(cells[5]) else { continue }

            read[cells[1]] = Measurement(perRound: perRound, link: link * 1000, once: 0)
        }

        return read
    }

    private static func moved(_ now: Double, from before: Double?) -> String {
        guard let before, before > 0 else { return "" }

        return String(format: "%+.1f%%", (now - before) / before * 100)
    }

    private static func table(
        _ measured: [String: Measurement],
        against: [String: Measurement]?,
        from path: String?,
        rounds: Int,
        repeats: Int
    ) -> String {
        let loop = measured[baseline]?.perRound ?? 0
        let heading = "rounds \(rounds), fastest of \(repeats);"
            + " link and once are the fastest of \(linkSamples)"
        var lines = [against == nil ? heading : heading + "; against \(path ?? "")", ""]

        lines += against == nil
            ? [
                "| workload | ns/round | minus loop | x loop | link us | once us |",
                "|---|---|---|---|---|---|"
            ]
            : [
                "| workload | ns/round | moved | x loop | link us | moved |",
                "|---|---|---|---|---|---|"
            ]

        for (name, measurement) in measured.sorted(by: { $0.key < $1.key }) {
            let ratio = loop > 0 ? measurement.perRound / loop : 0

            guard let before = against?[name] else {
                lines.append(String(
                    format: "| %@ | %.0f | %.0f | %.2f | %.0f | %.0f |",
                    name, measurement.perRound, measurement.perRound - loop, ratio,
                    measurement.link / 1000, measurement.once / 1000
                ))

                continue
            }

            lines.append(String(
                format: "| %@ | %.0f | %@ | %.2f | %.0f | %@ |",
                name, measurement.perRound, Self.moved(measurement.perRound, from: before.perRound),
                ratio, measurement.link / 1000, Self.moved(measurement.link, from: before.link)
            ))
        }

        return lines.joined(separator: "\n")
    }
}

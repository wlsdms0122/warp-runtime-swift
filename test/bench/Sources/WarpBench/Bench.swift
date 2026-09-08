//
//  Bench.swift
//  WarpBench
//
//  Created by JSilver on 9/2/26.
//

import Foundation

// Runs every program under `program/` and prints two tables. The first is
// nanoseconds per round and how that compares to the loop alone, beside the
// cost of linking the same program and the cost of a document that arrives,
// links, runs one round and is dropped. The second is the cost of linking a
// world as the number of documents in it grows.
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

    // Doubling rather than stepping: what the second table is read for is the
    // shape of the curve, and a shape shows over a range rather than between
    // neighbours.
    private static let chainCounts = [1, 2, 4, 8, 16, 32, 64, 128, 256]

    // MARK: - Initializer
    // MARK: - Public
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let numbers = arguments.prefix { argument in Int(argument) != nil }
        let rounds = numbers.first.flatMap(Int.init) ?? defaultRounds
        let repeats = numbers.dropFirst().first.flatMap(Int.init) ?? defaultRepeats
        let against = arguments.firstIndex(of: "--against").map { at in arguments[at + 1] }
        let printed = try against.map(Self.reading)
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

        var linkedByCount: [Int: Double] = [:]

        for count in chainCounts {
            let chain = try Chain(of: count)

            _ = try chain.link()

            var links: [Duration] = []

            for _ in 0 ..< linkSamples {
                links.append(try chain.link())
            }

            linkedByCount[chain.count] = Self.nanoseconds(Self.fastest(links))
        }

        print(Self.table(
            measured,
            against: printed?["workload"],
            from: against,
            rounds: rounds,
            repeats: repeats
        ))
        print("")
        print(Self.table(linkedByCount, against: printed?["documents"]))
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

    // The tables this printed earlier: each one under what its first column
    // calls its rows, and then by row and by heading.
    //
    // A table apiece rather than every row in one, because a row label only
    // means something under the table it was printed in: one table calls its
    // rows by workload and the other by a count, and nothing stops a program
    // under `program/` from being named a number. The figures are read under
    // the heading they were printed under rather than by position, so neither
    // table is held to a column order. Whatever a column holds that is not a
    // number is not a figure, which is how the moved columns of an earlier
    // comparison are passed over.
    private static func reading(_ path: String) throws -> [String: [String: [String: Double]]] {
        var read: [String: [String: [String: Double]]] = [:]
        var headings: [String] = []
        var above: [String] = []

        for line in try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n") {
            let cells = line.split(separator: "|").map { cell in cell.trimmingCharacters(in: .whitespaces) }

            guard let label = cells.first else { continue }

            if cells.allSatisfy({ cell in !cell.isEmpty && cell.allSatisfy { character in character == "-" } }) {
                headings = above

                continue
            }

            above = cells

            guard let rows = headings.first else { continue }

            read[rows, default: [:]][label] = Dictionary(
                zip(headings, cells).compactMap { heading, cell in Double(cell).map { read in (heading, read) } },
                uniquingKeysWith: { first, _ in first }
            )
        }

        return read
    }

    private static func moved(_ now: Double, from before: Double?) -> String {
        guard let before, before > 0 else { return "" }

        return String(format: "%+.1f%%", (now - before) / before * 100)
    }

    private static func table(
        _ measured: [String: Measurement],
        against: [String: [String: Double]]?,
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
                name, measurement.perRound, Self.moved(measurement.perRound, from: before["ns/round"]),
                ratio, measurement.link / 1000, Self.moved(measurement.link / 1000, from: before["link us"])
            ))
        }

        return lines.joined(separator: "\n")
    }

    // What linking a world costs as the number of documents in it grows.
    //
    // Beside the total, what one more document adds: the standard vocabulary is
    // in every one of these worlds, so the total carries a cost the count does
    // not move, and subtracting the smallest world is what leaves the count's
    // own. A column that holds still as the count doubles is a link growing
    // with its world rather than with the square of it.
    private static func table(_ linkedByCount: [Int: Double], against: [String: [String: Double]]?) -> String {
        let counts = linkedByCount.keys.sorted()

        guard let smallest = counts.first, let base = linkedByCount[smallest], base > 0 else { return "" }

        var lines = [
            "linking a chain of documents, each calling the one in front of it;"
                + " fastest of \(linkSamples)",
            "",
            against == nil
                ? "| documents | link us | x \(smallest) | us each |"
                : "| documents | link us | x \(smallest) | us each | moved |",
            against == nil ? "|---|---|---|---|" : "|---|---|---|---|---|"
        ]

        for count in counts {
            guard let link = linkedByCount[count] else { continue }

            let each = count > smallest
                ? String(format: "%.1f", (link - base) / Double(count - smallest) / 1000)
                : ""
            let figures = String(
                format: "| %d | %.0f | %.2f | %@ |",
                count, link / 1000, link / base, each
            )

            guard let against else {
                lines.append(figures)

                continue
            }

            lines.append(figures + String(
                format: " %@ |",
                Self.moved(link / 1000, from: against["\(count)"]?["link us"])
            ))
        }

        return lines.joined(separator: "\n")
    }
}

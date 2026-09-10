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
// chain of words as the chain grows, once with the words spread one to a
// document and once with all of them in one, so that a figure says which of
// the two a link is paying for.
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
            var bakes: [Duration] = []
            var onces: [Duration] = []

            for _ in 0 ..< linkSamples {
                links.append(try workload.link())
                bakes.append(try workload.baked())
                onces.append(try await workload.once())
            }

            measured[workload.name] = Measurement(
                perRound: Self.nanoseconds(Self.fastest(samples)) / Double(rounds),
                link: Self.nanoseconds(Self.fastest(links)),
                baked: Self.nanoseconds(Self.fastest(bakes)),
                once: Self.nanoseconds(Self.fastest(onces))
            )
        }

        var spread: [Int: Double] = [:]
        var gathered: [Int: Double] = [:]

        for count in chainCounts {
            let apart = try Chain(of: count, across: count)
            let together = try Chain(of: count, across: 1)

            spread[apart.words] = try Self.linking(apart)
            gathered[together.words] = try Self.linking(together)
        }

        print(Self.table(
            measured,
            against: printed?["workload"],
            from: against,
            rounds: rounds,
            repeats: repeats
        ))
        print("")
        print(Self.table(spread: spread, gathered: gathered, against: printed?["words"]))
    }

    // MARK: - Private
    private struct Measurement {
        let perRound: Double
        let link: Double
        let baked: Double
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

    // Nanoseconds the fastest of many links of one world took.
    private static func linking(_ chain: Chain) throws -> Double {
        _ = try chain.link()

        var links: [Duration] = []

        for _ in 0 ..< linkSamples {
            links.append(try chain.link())
        }

        return Self.nanoseconds(Self.fastest(links))
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
                "| workload | ns/round | minus loop | x loop | link us | baked us | once us |",
                "|---|---|---|---|---|---|---|"
            ]
            : [
                "| workload | ns/round | moved | x loop | link us | moved | baked us | moved |",
                "|---|---|---|---|---|---|---|---|"
            ]

        for (name, measurement) in measured.sorted(by: { $0.key < $1.key }) {
            let ratio = loop > 0 ? measurement.perRound / loop : 0

            guard let before = against?[name] else {
                lines.append(String(
                    format: "| %@ | %.0f | %.0f | %.2f | %.0f | %.0f | %.0f |",
                    name, measurement.perRound, measurement.perRound - loop, ratio,
                    measurement.link / 1000, measurement.baked / 1000, measurement.once / 1000
                ))

                continue
            }

            lines.append(String(
                format: "| %@ | %.0f | %@ | %.2f | %.0f | %@ | %.0f | %@ |",
                name, measurement.perRound, Self.moved(measurement.perRound, from: before["ns/round"]),
                ratio, measurement.link / 1000, Self.moved(measurement.link / 1000, from: before["link us"]),
                measurement.baked / 1000, Self.moved(measurement.baked / 1000, from: before["baked us"])
            ))
        }

        return lines.joined(separator: "\n")
    }

    // What linking a chain of words costs, once with the words dealt one to a
    // document and once with all of them in a single document.
    //
    // Beside each total, what one more word adds: the standard vocabulary is in
    // every one of these worlds, so a total carries a cost the count does not
    // move, and subtracting the smallest chain is what leaves the count's own.
    //
    // The two series carry the same words, the same bodies and the same names,
    // and differ only in how many documents hold them. A column that climbs on
    // both is a link growing with the words it was given; one that climbs only
    // where the words are spread is a link growing with the documents.
    private static func table(
        spread: [Int: Double],
        gathered: [Int: Double],
        against: [String: [String: Double]]?
    ) -> String {
        let counts = spread.keys.sorted()

        guard
            let smallest = counts.first,
            let spreadBase = spread[smallest], spreadBase > 0,
            let gatheredBase = gathered[smallest], gatheredBase > 0
        else { return "" }

        var lines = [
            "linking a chain of words, each calling the one in front of it;"
                + " spread one to a document and gathered into one; fastest of \(linkSamples)",
            "",
            against == nil
                ? "| words | spread us | spread each | gathered us | gathered each |"
                : "| words | spread us | spread each | gathered us | gathered each |"
                    + " spread moved | gathered moved |",
            against == nil ? "|---|---|---|---|---|" : "|---|---|---|---|---|---|---|"
        ]

        for count in counts {
            guard let apart = spread[count], let together = gathered[count] else { continue }

            let figures = String(
                format: "| %d | %.0f | %@ | %.0f | %@ |",
                count,
                apart / 1000, Self.each(apart, over: spreadBase, from: smallest, to: count),
                together / 1000, Self.each(together, over: gatheredBase, from: smallest, to: count)
            )

            guard let against else {
                lines.append(figures)

                continue
            }

            lines.append(figures + String(
                format: " %@ | %@ |",
                Self.moved(apart / 1000, from: against["\(count)"]?["spread us"]),
                Self.moved(together / 1000, from: against["\(count)"]?["gathered us"])
            ))
        }

        return lines.joined(separator: "\n")
    }

    // Microseconds each word past the smallest chain added, where any did.
    private static func each(_ link: Double, over base: Double, from smallest: Int, to count: Int) -> String {
        guard count > smallest else { return "" }

        return String(format: "%.1f", (link - base) / Double(count - smallest) / 1000)
    }
}

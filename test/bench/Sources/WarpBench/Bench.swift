//
//  Bench.swift
//  WarpBench
//
//  Created by JSilver on 9/2/26.
//

import Foundation

// Runs every program under `program/` and prints three tables. The first is
// nanoseconds per round and how that compares to the loop alone, beside what
// the same program costs to arrive as text, to build, and to build and run one
// round and be dropped. The second is the cost of building a chain of procedures as
// the chain grows, once with the procedures spread one to a document and once with
// all of them in one, so that a figure says which of the two a build is paying
// for. The third holds one count of procedures and deals them into more and more
// documents, timing the two halves of the build apart, so that what a build
// could spread across cores is a figure rather than an estimate.
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

    // A build and a single round are one measurement each rather than a rate,
    // so they are sampled many times and the fastest reported.
    private static let buildSamples = 201
    private static let baseline = "loop"

    // Doubling rather than stepping: what the second table is read for is the
    // curve, and a curve shows over a range rather than between neighbours.
    private static let chainCounts = [1, 2, 4, 8, 16, 32, 64, 128, 256]

    // One count of procedures dealt into more and more documents, doubling for the
    // same reason the chain's counts do.
    private static let documentCounts = [1, 2, 4, 8, 16, 32, 64, 128, 256]

    // As many procedures as the most documents, so the widest spread is one procedure to
    // a document.
    private static let fanoutWords = documentCounts.reduce(1, max)

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

            var loads: [Duration] = []
            var builds: [Duration] = []
            var bakes: [Duration] = []
            var onces: [Duration] = []

            for _ in 0 ..< buildSamples {
                loads.append(try workload.load())
                builds.append(try workload.build())
                bakes.append(try workload.baked())
                onces.append(try await workload.once())
            }

            measured[workload.name] = Measurement(
                perRound: Self.nanoseconds(Self.fastest(samples)) / Double(rounds),
                load: Self.nanoseconds(Self.fastest(loads)),
                build: Self.nanoseconds(Self.fastest(builds)),
                baked: Self.nanoseconds(Self.fastest(bakes)),
                once: Self.nanoseconds(Self.fastest(onces))
            )
        }

        // Each table printed where it is finished rather than all three at the
        // end, so that a world further down refusing does not take the tables
        // already measured with it.
        print(Self.table(
            measured,
            against: printed?["workload"],
            from: against,
            rounds: rounds,
            repeats: repeats
        ))

        var spread: [Int: Double] = [:]
        var gathered: [Int: Double] = [:]

        for count in chainCounts {
            let apart = try Dealing(of: count, across: count)
            let together = try Dealing(of: count, across: 1)

            spread[apart.procedures] = try Self.fastest(Chain(apart).build)
            gathered[together.procedures] = try Self.fastest(Chain(together).build)
        }

        print("")
        print(Self.table(spread: spread, gathered: gathered, against: printed?["procedures"]))

        var costs: [Int: Cost] = [:]

        for count in documentCounts {
            let dealing = try Dealing(of: fanoutWords, across: count)
            let fanout = try Fanout(dealing)

            costs[dealing.documents] = Cost(
                build: try Self.fastest(fanout.build),
                compile: try Self.fastest(fanout.compile),
                alone: try Self.fastest(fanout.alone),
                link: try Self.fastest(fanout.link)
            )
        }

        print("")
        print(Self.table(costs, of: fanoutWords, against: printed?["documents"]))
    }

    // MARK: - Private
    private struct Measurement {
        let perRound: Double
        let load: Double
        let build: Double
        let baked: Double
        let once: Double
    }

    // What one world of fanned-out procedures costs, by the door that was asked.
    private struct Cost {
        let build: Double
        let compile: Double
        let alone: Double
        let link: Double
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

    // Nanoseconds the fastest of many samples of one act took. Warmed up once
    // first, so that whatever the first call alone pays is out of the samples.
    private static func fastest(_ act: () throws -> Duration) throws -> Double {
        _ = try act()

        var samples: [Duration] = []

        for _ in 0 ..< buildSamples {
            samples.append(try act())
        }

        return Self.nanoseconds(Self.fastest(samples))
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
            + " load, build, baked and once are the fastest of \(buildSamples)"
        var lines = [against == nil ? heading : heading + "; against \(path ?? "")", ""]

        lines += against == nil
            ? [
                "| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |",
                "|---|---|---|---|---|---|---|---|"
            ]
            : [
                "| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |",
                "|---|---|---|---|---|---|---|---|---|---|"
            ]

        for (name, measurement) in measured.sorted(by: { $0.key < $1.key }) {
            let ratio = loop > 0 ? measurement.perRound / loop : 0

            guard let before = against?[name] else {
                lines.append(String(
                    format: "| %@ | %.0f | %.0f | %.2f | %.0f | %.0f | %.0f | %.0f |",
                    name, measurement.perRound, measurement.perRound - loop, ratio,
                    measurement.load / 1000, measurement.build / 1000,
                    measurement.baked / 1000, measurement.once / 1000
                ))

                continue
            }

            lines.append(String(
                format: "| %@ | %.0f | %@ | %.2f | %.0f | %@ | %.0f | %@ | %.0f | %@ |",
                name, measurement.perRound, Self.moved(measurement.perRound, from: before["ns/round"]),
                ratio,
                measurement.load / 1000, Self.moved(measurement.load / 1000, from: before["load us"]),
                measurement.build / 1000, Self.moved(measurement.build / 1000, from: before["build us"]),
                measurement.baked / 1000, Self.moved(measurement.baked / 1000, from: before["baked us"])
            ))
        }

        return lines.joined(separator: "\n")
    }

    // What building a chain of procedures costs, once with the procedures dealt one to a
    // document and once with all of them in a single document.
    //
    // Beside each total, what one more procedure adds: the standard vocabulary is in
    // every one of these worlds, so a total carries a cost the count does not
    // move, and subtracting the smallest chain is what leaves the count's own.
    //
    // The two series carry the same procedures, the same bodies and the same names,
    // and differ only in how many documents hold them. A column that climbs on
    // both is a build growing with the procedures it was given; one that climbs only
    // where the procedures are spread is a build growing with the documents.
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
            "building a chain of procedures, each calling the one in front of it;"
                + " spread one to a document and gathered into one; fastest of \(buildSamples)",
            "",
            against == nil
                ? "| procedures | spread us | spread each | gathered us | gathered each |"
                : "| procedures | spread us | spread each | gathered us | gathered each |"
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

    // What one count of procedures costs to build as it is dealt into more and more
    // documents, with the two halves of the build timed apart.
    //
    // The procedures, the bodies and the names are the same in every row, and none
    // of them calls another, so nothing here grows with the count except what
    // having more documents costs. `compile` is the documents settled together
    // and `alone` the same documents settled one at a time, which is what a
    // build that handed each to its own core would have to do: the gap between
    // them is what a compile stops sharing once they are split. `link` lays
    // them down together and no spreading takes it away.
    //
    // `spread` is what the row would cost on as many cores as it has documents
    // and nothing else changed: one document's compile, and then the link. It
    // is a floor rather than a forecast, since it charges nothing for handing
    // the documents out or for taking the answers back.
    private static func table(
        _ costs: [Int: Cost],
        of procedures: Int,
        against: [String: [String: Double]]?
    ) -> String {
        var lines = [
            "building \(procedures) procedures that call nothing, dealt into documents,"
                + " against a vocabulary compiled once; fastest of \(buildSamples)",
            "",
            "`alone` is the documents compiled one at a time rather than together."
                + " `spread` is one document's share of that plus the link, which is"
                + " what the row costs on as many cores as it has documents and"
                + " nothing charged for handing them out; `x` is `build` over it.",
            "",
            against == nil
                ? "| documents | build us | compile us | alone us | link us | spread us | x |"
                : "| documents | build us | moved | compile us | moved | alone us | moved"
                    + " | link us | moved | spread us | x |",
            against == nil ? "|---|---|---|---|---|---|---|" : "|---|---|---|---|---|---|---|---|---|---|---|"
        ]

        for count in costs.keys.sorted() {
            guard let cost = costs[count] else { continue }

            let spread = cost.alone / Double(count) + cost.link
            let figures = String(
                format: "| %d | %.0f | %.0f | %.0f | %.0f | %.0f | %.2f |",
                count, cost.build / 1000, cost.compile / 1000, cost.alone / 1000,
                cost.link / 1000, spread / 1000, spread > 0 ? cost.build / spread : 0
            )

            guard let against else {
                lines.append(figures)

                continue
            }

            let before = against["\(count)"]

            lines.append(String(
                format: "| %d | %.0f | %@ | %.0f | %@ | %.0f | %@ | %.0f | %@ | %.0f | %.2f |",
                count,
                cost.build / 1000, Self.moved(cost.build / 1000, from: before?["build us"]),
                cost.compile / 1000, Self.moved(cost.compile / 1000, from: before?["compile us"]),
                cost.alone / 1000, Self.moved(cost.alone / 1000, from: before?["alone us"]),
                cost.link / 1000, Self.moved(cost.link / 1000, from: before?["link us"]),
                spread / 1000, spread > 0 ? cost.build / spread : 0
            ))
        }

        return lines.joined(separator: "\n")
    }

    // Microseconds each procedure past the smallest chain added, where any did.
    private static func each(_ build: Double, over base: Double, from smallest: Int, to count: Int) -> String {
        guard count > smallest else { return "" }

        return String(format: "%.1f", (build - base) / Double(count - smallest) / 1000)
    }
}

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
        let workloads = try await Self.workloads()

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
                builds.append(try await workload.build())
                bakes.append(try await workload.baked())
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

            spread[apart.procedures] = try await Self.fastest(Chain(apart).build)
            gathered[together.procedures] = try await Self.fastest(Chain(together).build)
        }

        print("")
        print(Self.table(
            spread: spread,
            gathered: gathered,
            against: printed?["procedures"],
            from: against
        ))

        var costs: [Int: Cost] = [:]

        for count in documentCounts {
            let dealing = try Dealing(of: fanoutWords, across: count)
            let fanout = try await Fanout(dealing)

            costs[dealing.documents] = Cost(
                build: try await Self.fastest(fanout.build),
                compile: try await Self.fastest(fanout.compile),
                alone: try await Self.fastest(fanout.alone),
                link: try Self.fastest(fanout.link)
            )
        }

        print("")
        print(Self.table(costs, of: fanoutWords, against: printed?["documents"], from: against))
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

    private static func workloads() async throws -> [Workload] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("program")
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "warpt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var workloads: [Workload] = []

        for file in files {
            workloads.append(try await Workload(reading: file))
        }

        return workloads
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

    // The same, for an act that suspends.
    private static func fastest(_ act: () async throws -> Duration) async throws -> Double {
        _ = try await act()

        var samples: [Duration] = []

        for _ in 0 ..< buildSamples {
            samples.append(try await act())
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
                zip(headings, cells).compactMap { heading, cell in
                    Double(cell).map { figure in (heading, figure) }
                },
                uniquingKeysWith: { first, _ in first }
            )
        }

        return read
    }

    // A table read to compare a run against, and what it turned out not to
    // carry.
    //
    // A table taken before a figure existed is not a table this run moved from,
    // and the figure beside a missing one is the worst of it: the columns keep
    // their spellings while what they measure is split, so the arithmetic runs
    // and reads as a change. So a table that is missing any figure the table
    // asking compares is not compared at all, and the reader is told which
    // figure said so.
    //
    // Which figures those are is the asking table's, said beside the rows that
    // read them.
    private struct Comparison {
        // MARK: - Property
        let rows: [String: [String: Double]]?

        private let missing: String?
        private let path: String?

        // MARK: - Initializer
        init(_ read: [String: [String: Double]]?, over figures: [String], from path: String?) {
            self.path = path

            guard let path else {
                self.rows = nil
                self.missing = nil

                return
            }

            guard let read else {
                self.rows = nil
                self.missing = "does not carry this table"

                return
            }

            let absent = figures.filter { figure in
                read.values.allSatisfy { row in row[figure] == nil }
            }

            guard absent.isEmpty else {
                self.rows = nil
                self.missing = "carries no "
                    + absent.map { figure in "`\(figure)`" }.joined(separator: ", ")

                return
            }

            self.rows = read
            self.missing = nil
        }

        // MARK: - Public
        // The heading, saying what this run was read against or why it was not.
        func said(beside heading: String) -> String {
            guard let path else { return heading }

            guard let missing else { return heading + "; against \(path)" }

            return heading + "\n\nNot compared against \(path): it \(missing)."
                + " Take it again before reading this against it."
        }

        // MARK: - Private
    }

    // One column of the workload table: what it is called, what it reads for a
    // workload, and what a table compared against is asked for where the
    // column moves at all.
    //
    // A column named once is a column that cannot be printed and not compared,
    // which is what happened twice while the name lived in five places.
    private struct Column: Sendable {
        let heading: String

        // What it reads, said once: the cell and the comparison stand on the
        // same arithmetic rather than on two copies of it.
        let read: @Sendable (Measurement, Double) -> Double

        let decimals: Int

        // Whether a table compared against is asked for this. A column read
        // off the loop of this same run has nothing to move from.
        let moves: Bool

        func text(_ measurement: Measurement, over loop: Double) -> String {
            String(format: "%.\(decimals)f", read(measurement, loop))
        }
    }

    private static let columns: [Column] = [
        Column(
            heading: "ns/round",
            read: { measurement, _ in measurement.perRound },
            decimals: 0,
            moves: true
        ),
        Column(
            heading: "minus loop",
            read: { measurement, loop in measurement.perRound - loop },
            decimals: 0,
            moves: false
        ),
        Column(
            heading: "x loop",
            read: { measurement, loop in loop > 0 ? measurement.perRound / loop : 0 },
            decimals: 2,
            moves: false
        ),
        Column(
            heading: "load us",
            read: { measurement, _ in measurement.load / 1000 },
            decimals: 0,
            moves: true
        ),
        Column(
            heading: "build us",
            read: { measurement, _ in measurement.build / 1000 },
            decimals: 0,
            moves: true
        ),
        Column(
            heading: "baked us",
            read: { measurement, _ in measurement.baked / 1000 },
            decimals: 0,
            moves: true
        ),
        Column(
            heading: "once us",
            read: { measurement, _ in measurement.once / 1000 },
            decimals: 0,
            moves: true
        )
    ]

    private static func moved(_ now: Double, from before: Double?) -> String {
        guard let before, before > 0 else { return "" }

        return String(format: "%+.1f%%", (now - before) / before * 100)
    }

    private static func table(
        _ measured: [String: Measurement],
        against read: [String: [String: Double]]?,
        from path: String?,
        rounds: Int,
        repeats: Int
    ) -> String {
        let comparison = Comparison(
            read,
            over: columns.filter(\.moves).map(\.heading),
            from: path
        )
        let loop = measured[baseline]?.perRound ?? 0
        let against = comparison.rows
        let heading = "rounds \(rounds), fastest of \(repeats);"
            + " load, build, baked and once are the fastest of \(buildSamples)"

        // Heading, rule and rows all read the same list, so a column is added
        // once and a column that moves is compared because it said it does.
        let headings = columns.flatMap { column in
            against == nil || !column.moves ? [column.heading] : [column.heading, "moved"]
        }

        var lines = [
            comparison.said(beside: heading),
            "",
            "| workload | " + headings.joined(separator: " | ") + " |",
            "|---" + String(repeating: "|---", count: headings.count) + "|"
        ]

        for (name, measurement) in measured.sorted(by: { $0.key < $1.key }) {
            let before = against?[name]

            let cells = columns.flatMap { column -> [String] in
                let cell = column.text(measurement, over: loop)

                guard against != nil, column.moves else { return [cell] }

                return [
                    cell,
                    Self.moved(column.read(measurement, loop), from: before?[column.heading])
                ]
            }

            lines.append("| " + name + " | " + cells.joined(separator: " | ") + " |")
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
        against read: [String: [String: Double]]?,
        from path: String?
    ) -> String {
        let comparison = Comparison(read, over: ["spread us", "gathered us"], from: path)
        let against = comparison.rows
        let counts = spread.keys.sorted()

        guard
            let smallest = counts.first,
            let spreadBase = spread[smallest], spreadBase > 0,
            let gatheredBase = gathered[smallest], gatheredBase > 0
        else { return "" }

        var lines = [
            comparison.said(beside: "building a chain of procedures, each calling the one in"
                + " front of it; spread one to a document and gathered into one; fastest of"
                + " \(buildSamples)"),
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
        against read: [String: [String: Double]]?,
        from path: String?
    ) -> String {
        let comparison = Comparison(
            read,
            over: ["build us", "compile us", "alone us", "link us"],
            from: path
        )
        let against = comparison.rows

        var lines = [
            comparison.said(beside: "building \(procedures) procedures that call nothing,"
                + " dealt into documents, against a vocabulary compiled once; fastest of"
                + " \(buildSamples)"),
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

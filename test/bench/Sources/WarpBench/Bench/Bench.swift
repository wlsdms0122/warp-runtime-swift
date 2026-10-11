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
    private enum Refusal: Error, CustomStringConvertible {
        // `--against` names the table it reads next.
        case tableless

        // MARK: - Property
        var description: String { "--against takes the path of a table this bench printed" }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    private struct Measurement {
        // MARK: - Property
        let perRound: Double
        let load: Double
        let build: Double
        let baked: Double
        let once: Double

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // What one build of fanned-out procedures costs, by the door that was asked.
    private struct Cost {
        // MARK: - Property
        let build: Double
        let compile: Double
        let alone: Double
        let link: Double

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
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

            guard path != nil else {
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

    // One column of a table: what it is called, what it prints for a row, and
    // what a table compared against is asked for where the column moves at
    // all. The heading is named once, so a column is printed and compared
    // under one spelling.
    private struct Column<Row> {
        // MARK: - Property
        let heading: String

        // The cell, for a row.
        let text: (Row) -> String

        // What it reads, where it moves: the cell and the comparison stand on
        // the same arithmetic rather than on two copies of it. Nil for a
        // column read off the loop of this same run, which has nothing to
        // move from.
        let read: ((Row) -> Double)?

        // MARK: - Initializer
        // MARK: - Public
        // A figure printed to a number of decimals.
        static func figure(
            _ heading: String,
            decimals: Int,
            moves: Bool,
            _ read: @escaping (Row) -> Double
        ) -> Column {
            Column(
                heading: heading,
                text: { row in String(format: "%.\(decimals)f", read(row)) },
                read: moves ? read : nil
            )
        }

        // MARK: - Private
    }

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
    private static let fanoutProcedures = documentCounts.reduce(1, max)

    // MARK: - Initializer
    // MARK: - Public
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let numbers = arguments.prefix { argument in Int(argument) != nil }
        let rounds = numbers.first.flatMap(Int.init) ?? defaultRounds
        let repeats = numbers.dropFirst().first.flatMap(Int.init) ?? defaultRepeats
        let against = try arguments.firstIndex(of: "--against").map { at in
            guard arguments.indices.contains(at + 1) else { throw Refusal.tableless }

            return arguments[at + 1]
        }
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
        // end, so that a build further down refusing does not take the tables
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
            let dealing = try Dealing(of: fanoutProcedures, across: count)
            let fanout = try await Fanout(dealing)

            costs[dealing.documents] = Cost(
                build: try await Self.fastest(fanout.build),
                compile: try await Self.fastest(fanout.compile),
                alone: try await Self.fastest(fanout.alone),
                link: try Self.fastest(fanout.link)
            )
        }

        print("")
        print(Self.table(costs, of: fanoutProcedures, against: printed?["documents"], from: against))
    }

    // MARK: - Private
    private static func workloads() async throws -> [Workload] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("program")
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { file in file.pathExtension == "warpt" }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }

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

    private static func moved(_ now: Double, from before: Double?) -> String {
        guard let before, before > 0 else { return "" }

        return String(format: "%+.1f%%", (now - before) / before * 100)
    }

    // Heading, rule and rows all read the one list of columns, so a column is
    // added once and a column that moves is compared because it said it does.
    private static func table<Row>(
        _ rows: [(label: String, row: Row)],
        labelled first: String,
        columns: [Column<Row>],
        against read: [String: [String: Double]]?,
        from path: String?,
        under heading: String,
        noting notes: [String] = []
    ) -> String {
        let comparison = Comparison(
            read,
            over: columns.compactMap { column in column.read == nil ? nil : column.heading },
            from: path
        )
        let against = comparison.rows
        let headings = columns.flatMap { column in
            against == nil || column.read == nil ? [column.heading] : [column.heading, "moved"]
        }

        var lines = [comparison.said(beside: heading), ""]
        lines += notes.flatMap { note in [note, ""] }
        lines += [
            "| \(first) | " + headings.joined(separator: " | ") + " |",
            "|---" + String(repeating: "|---", count: headings.count) + "|"
        ]

        for (label, row) in rows {
            let before = against?[label]

            let cells = columns.flatMap { column -> [String] in
                let cell = column.text(row)

                guard against != nil, let read = column.read else { return [cell] }

                return [cell, Self.moved(read(row), from: before?[column.heading])]
            }

            lines.append("| " + label + " | " + cells.joined(separator: " | ") + " |")
        }

        return lines.joined(separator: "\n")
    }

    private static func table(
        _ measured: [String: Measurement],
        against read: [String: [String: Double]]?,
        from path: String?,
        rounds: Int,
        repeats: Int
    ) -> String {
        let loop = measured[baseline]?.perRound ?? 0
        let columns: [Column<Measurement>] = [
            .figure("ns/round", decimals: 0, moves: true) { measurement in measurement.perRound },
            .figure("minus loop", decimals: 0, moves: false) { measurement in measurement.perRound - loop },
            .figure("x loop", decimals: 2, moves: false) { measurement in loop > 0 ? measurement.perRound / loop : 0 },
            .figure("load us", decimals: 0, moves: true) { measurement in measurement.load / 1000 },
            .figure("build us", decimals: 0, moves: true) { measurement in measurement.build / 1000 },
            .figure("baked us", decimals: 0, moves: true) { measurement in measurement.baked / 1000 },
            .figure("once us", decimals: 0, moves: true) { measurement in measurement.once / 1000 }
        ]

        return table(
            measured
                .sorted { one, other in one.key < other.key }
                .map { name, measurement in (label: name, row: measurement) },
            labelled: "workload",
            columns: columns,
            against: read,
            from: path,
            under: "rounds \(rounds), fastest of \(repeats);"
                + " load, build, baked and once are the fastest of \(buildSamples)"
        )
    }

    // What building a chain of procedures costs, once with the procedures dealt one to a
    // document and once with all of them in a single document.
    //
    // Beside each total, what one more procedure adds: the standard vocabulary is in
    // every one of these builds, so a total carries a cost the count does not
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
        typealias Chained = (count: Int, apart: Double, together: Double)

        let counts = spread.keys.sorted()

        guard
            let smallest = counts.first,
            let spreadBase = spread[smallest], spreadBase > 0,
            let gatheredBase = gathered[smallest], gatheredBase > 0
        else { return "" }

        let columns: [Column<Chained>] = [
            .figure("spread us", decimals: 0, moves: true) { chained in chained.apart / 1000 },
            Column(
                heading: "spread each",
                text: { chained in Self.each(chained.apart, over: spreadBase, from: smallest, to: chained.count) },
                read: nil
            ),
            .figure("gathered us", decimals: 0, moves: true) { chained in chained.together / 1000 },
            Column(
                heading: "gathered each",
                text: { chained in Self.each(chained.together, over: gatheredBase, from: smallest, to: chained.count) },
                read: nil
            )
        ]
        let rows: [(label: String, row: Chained)] = counts.compactMap { count in
            guard let apart = spread[count], let together = gathered[count] else { return nil }

            return (label: "\(count)", row: (count: count, apart: apart, together: together))
        }

        return table(
            rows,
            labelled: "procedures",
            columns: columns,
            against: read,
            from: path,
            under: "building a chain of procedures, each calling the one in"
                + " front of it; spread one to a document and gathered into one; fastest of"
                + " \(buildSamples)"
        )
    }

    // What one count of procedures costs to build as it is dealt into more and more
    // documents, with the two halves of the build timed apart.
    //
    // The procedures, the bodies and the names are the same in every row, and none
    // of them calls another, so nothing here grows with the count except what
    // having more documents costs. `compile` is the documents compiled together
    // and `alone` the same documents compiled one at a time, which is what a
    // build that handed each to its own core would have to do: the gap between
    // them is what a compile stops sharing once they are split. `link` lays
    // them down together and no spreading takes it away. The table's note
    // says what `floor` is.
    private static func table(
        _ costs: [Int: Cost],
        of procedures: Int,
        against read: [String: [String: Double]]?,
        from path: String?
    ) -> String {
        typealias Dealt = (count: Int, cost: Cost)

        let floor: (Dealt) -> Double = { dealt in dealt.cost.alone / Double(dealt.count) + dealt.cost.link }
        let columns: [Column<Dealt>] = [
            .figure("build us", decimals: 0, moves: true) { dealt in dealt.cost.build / 1000 },
            .figure("compile us", decimals: 0, moves: true) { dealt in dealt.cost.compile / 1000 },
            .figure("alone us", decimals: 0, moves: true) { dealt in dealt.cost.alone / 1000 },
            .figure("link us", decimals: 0, moves: true) { dealt in dealt.cost.link / 1000 },
            .figure("floor us", decimals: 0, moves: false) { dealt in floor(dealt) / 1000 },
            .figure("x", decimals: 2, moves: false) { dealt in
                floor(dealt) > 0 ? dealt.cost.build / floor(dealt) : 0
            }
        ]
        let rows: [(label: String, row: Dealt)] = costs.keys.sorted().compactMap { count in
            costs[count].map { cost in (label: "\(count)", row: (count: count, cost: cost)) }
        }

        return table(
            rows,
            labelled: "documents",
            columns: columns,
            against: read,
            from: path,
            under: "building \(procedures) procedures that call nothing,"
                + " dealt into documents, against a vocabulary compiled once; fastest of"
                + " \(buildSamples)",
            noting: [
                "`alone` is the documents compiled one at a time rather than together."
                    + " `floor` is one document's share of that plus the link, which is"
                    + " what the row costs on as many cores as it has documents and"
                    + " nothing charged for handing them out; `x` is `build` over it."
            ]
        )
    }

    // Microseconds each procedure past the smallest chain added, where any did.
    private static func each(_ build: Double, over base: Double, from smallest: Int, to count: Int) -> String {
        guard count > smallest else { return "" }

        return String(format: "%.1f", (build - base) / Double(count - smallest) / 1000)
    }
}

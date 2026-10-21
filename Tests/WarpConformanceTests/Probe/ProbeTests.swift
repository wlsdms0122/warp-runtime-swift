//
//  ProbeTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/22/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// Cases of one's own, in the folder `PROBE_DIR` names, asked through `Runner`.
// One line per case says what it got and whether that held against what it
// expects. `PROBE_ONLY` asks only the cases whose names start with it,
// `PROBE_OUT` names a file every line is also appended to, and `PROBE_REWRITE`
// a folder each program case is written to with its `expect` replaced by what
// it got, in the writer's layout.
@Suite("Cases of one's own", .enabled(if: ProcessInfo.processInfo.environment["PROBE_DIR"] != nil))
struct ProbeTests {
    // MARK: - Property
    private let runner = Runner()
    private let environment = ProcessInfo.processInfo.environment

    // MARK: - Initializer
    // MARK: - Test
    @Test("every case in the probe folder")
    func probeFolder() async throws {
        let folder = URL(fileURLWithPath: try #require(environment["PROBE_DIR"]))
        let only = environment["PROBE_ONLY"] ?? ""
        let out = environment["PROBE_OUT"].map { path in URL(fileURLWithPath: path) }
        let rewrite = environment["PROBE_REWRITE"].map { path in URL(fileURLWithPath: path) }
        let files = try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { file in file.lastPathComponent.hasSuffix(Case.suffix) && file.lastPathComponent.hasPrefix(only) }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }

        for file in files {
            let name = String(file.lastPathComponent.dropLast(Case.suffix.count))
            let written: Value
            let sut: Case

            do {
                written = try TextEncoding().value(from: try Data(contentsOf: file))
                sut = try Case(from: written, in: name)
            } catch {
                try record("PROBE \(name) | CASE-UNREADABLE \(error)", into: out)

                continue
            }

            switch sut.asked {
            case let .program(program):
                let probe = await Probe(asking: program, through: runner)

                try record(line(name, program, probe), into: out)

                if let rewrite, let got = got(program, probe) {
                    do {
                        try write(written, expecting: got, to: rewrite.appendingPathComponent(file.lastPathComponent))
                    } catch {
                        Issue.record("\(name) is not rewritten: \(error)")
                    }
                }

            case let .object(object):
                try record(await line(name, object), into: out)

            case let .encoded(encoded, reading):
                try record(line(name, encoded, reading), into: out)
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func line(_ name: String, _ program: Case.Program, _ probe: Probe) -> String {
        let expected = switch program.expectation {
        case let .answers(value): "answers \(value)"
        case let .refuses(stage): "refuses \(stage)"
        case .builds: "builds"
        }
        var line = "PROBE \(name) | expected: \(expected) | got: "
        var held = false

        switch probe.outcome {
        case let .refused(refusal):
            line += "refused \(refusal.stage): \(refusal.error)"

            if case let .refuses(stage) = program.expectation { held = refusal.stage == stage }

        case let .answered(answered, roundTrip):
            line += "answers \(answered)"

            if case let .answers(expected) = program.expectation {
                held = answered.matchesStrictly(expected, text: .value)

                if !held { line += " | ANSWER DIFFERS" }
            }

            switch roundTrip {
            case let .success(again) where again == answered:
                line += " | roundtrip same"

            case let .success(again):
                line += " | ROUNDTRIP DIFFERS: \(again)"
                held = false

            case let .failure(error):
                line += " | ROUNDTRIP ERROR: \(error)"
                held = false
            }

        case let .threw(error):
            line += "THREW \(error)"
        }

        if case let .builds(expected) = program.expectation, let built = probe.built {
            switch built {
            case let .success(built) where built.matchesStrictly(expected, text: .scalars):
                line += " | builds same"
                held = true

            case .success:
                line += " | BUILDS DIFFERS"
                held = false

            case let .failure(error):
                line += " | BUILDS THREW \(error)"
                held = false
            }
        }

        return (held ? "HELD " : "MISMATCH ") + line
    }

    private func line(_ name: String, _ object: Case.Object) async -> String {
        let expected = switch object.expectation {
        case let .answers(value): "answers \(value)"
        case let .refuses(stage): "refuses \(stage)"
        }
        var line = "PROBE \(name) | expected: \(expected) | got: "
        var held = false

        do {
            if let refusal = try await runner.reached(object) {
                line += "refused \(refusal.stage): \(refusal.error)"

                if case let .refuses(stage) = object.expectation { held = refusal.stage == stage }
            } else {
                let answered = try await runner.run(object)

                line += "answers \(answered)"

                if case let .answers(expected) = object.expectation {
                    held = answered.matchesStrictly(expected, text: .value)

                    if !held { line += " | ANSWER DIFFERS" }
                }
            }
        } catch {
            line += "THREW \(error)"
        }

        return (held ? "HELD " : "MISMATCH ") + "OBJECT " + line
    }

    private func line(_ name: String, _ encoded: Case.Encoded, _ reading: Case.Reading) -> String {
        let expected = switch reading {
        case let .reads(value): "reads \(value)"
        case let .spells(value): "spells \(value)"
        case .refuses: "refuses"
        }
        var line = "PROBE \(name) | expected: \(expected) | got: "
        let held: Bool

        do {
            let read = try encoded.read()

            line += "reads \(read)"

            switch reading {
            case let .reads(value):
                held = read.matchesStrictly(value, text: .scalars)

            case let .spells(value):
                let writesBack = (try? encoded.written(value)) == encoded.data

                line += writesBack ? " | writes back same" : " | WRITES BACK OTHERWISE"
                held = read.matchesStrictly(value, text: .scalars) && writesBack

            case .refuses:
                held = false
            }
        } catch {
            line += "refused reading: \(error)"

            if case .refuses = reading { held = true } else { held = false }
        }

        return (held ? "HELD " : "MISMATCH ") + "ENCODED " + line
    }

    // What a program case got, as its `expect` would say it: the object a
    // `builds` case builds, otherwise the stage it was refused at or what it
    // answered. Nil where it got none of these.
    private func got(_ program: Case.Program, _ probe: Probe) -> Value? {
        if case .builds = program.expectation {
            guard case let .success(built)? = probe.built else { return nil }

            return ["builds": built]
        }

        switch probe.outcome {
        case let .refused(refusal): return ["refuses": .string(refusal.stage.rawValue)]
        case let .answered(answered, _): return ["answers": answered]
        case .threw: return nil
        }
    }

    // A line is one line, so the newlines in what a case got are escaped.
    private func record(_ line: String, into out: URL?) throws {
        let escaped = line.replacingOccurrences(of: "\n", with: "\\n")

        print(escaped)

        guard let out else { return }

        let data = Data((escaped + "\n").utf8)

        guard let handle = try? FileHandle(forWritingTo: out) else {
            try data.write(to: out)

            return
        }

        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    private func write(_ written: Value, expecting got: Value, to file: URL) throws {
        guard case let .dictionary(fields) = written else { return }

        let text = try TextEncoding().text(from: .dictionary(fields.writing("expect", with: got)))

        try text.write(to: file, atomically: true, encoding: .utf8)
    }
}

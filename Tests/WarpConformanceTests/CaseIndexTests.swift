//
//  CaseIndexTests.swift
//  WarpConformanceTests
//
//  Created by JSilver
//

import Foundation
import Testing

// The specification names its own cases: each page ends with the cases that
// measure it, so a reader who has a rule has the case beside it.
//
// Which page a case belongs under is a judgment nothing derives. What is not a
// judgment is whether the naming is whole, and that is what this asks: a name
// no file answers, a case no page names, and a case two pages claim are each a
// listing that has drifted from the folder it describes.
@Suite("The specification names its cases")
struct CaseIndexTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every name a page lists is a case")
    func everyListedNameIsACase() throws {
        let listed = try Self.listed()
        let cases = try Self.cases()
        let unfound = listed.filter { one in !cases.contains(one.name) }
            .map { one in "\(one.page) lists '\(one.name)'" }

        #expect(unfound.isEmpty, "named and not there: \(unfound.joined(separator: ", "))")
    }

    @Test("every case is listed by exactly one page")
    func everyCaseIsListedOnce() throws {
        let listed = try Self.listed()
        let cases = try Self.cases()
        let pages = Dictionary(grouping: listed, by: \.name).mapValues { entries in entries.map(\.page) }
        let unlisted = cases.filter { name in pages[name] == nil }.sorted()
        let twice = pages.filter { entry in entry.value.count > 1 }
            .map { entry in "'\(entry.key)' is on \(entry.value.sorted().joined(separator: " and "))" }
            .sorted()

        #expect(unlisted.isEmpty, "no page names: \(unlisted.joined(separator: ", "))")
        #expect(twice.isEmpty, "named twice: \(twice.joined(separator: ", "))")
    }

    @Test("every page lists its cases in name order")
    func everyListingIsInOrder() throws {
        // By scalar, the order every implementation sorts the same way. A
        // page may group its cases under lead-ins, and each group is in order
        // on its own.
        let unordered = Dictionary(grouping: try Self.listed(), by: \.page)
            .filter { entry in
                Dictionary(grouping: entry.value, by: \.group).values.contains { group in
                    let names = group.map(\.name)

                    return names != names.sorted { one, other in one.unicodeScalars.lexicographicallyPrecedes(other.unicodeScalars) }
                }
            }
            .keys
            .sorted()

        #expect(unordered.isEmpty, "not in name order: \(unordered.joined(separator: ", "))")
    }

    // MARK: - Private
    private static let specification = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // WarpConformanceTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // warp-runtime-swift
        .deletingLastPathComponent()   // runtime
        .deletingLastPathComponent()   // the repository
        .appendingPathComponent("spec")

    private static func cases() throws -> Set<String> {
        Set(
            try FileManager.default
                .contentsOfDirectory(at: specification.appendingPathComponent("conformance"), includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
                .filter { file in file.hasSuffix(".test.warpt") }
                .map { file in String(file.dropLast(".test.warpt".count)) }
        )
    }

    // Every name written under a page's `Cases` heading, beside the page that
    // wrote it. The heading closes the section: a name written anywhere else on
    // the page is prose about one case rather than the page's listing of them.
    private static func listed() throws -> [(page: String, group: Int, name: String)] {
        try FileManager.default
            .contentsOfDirectory(at: specification, includingPropertiesForKeys: nil)
            .filter { file in file.pathExtension == "md" }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }
            .flatMap { file in
                let page = file.lastPathComponent
                let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)

                guard let opened = lines.firstIndex(of: "## Cases") else { return [(page: String, group: Int, name: String)]() }

                // A run of names is one group, and a line that is not a name
                // between two runs starts another.
                var group = 0
                var listed: [(page: String, group: Int, name: String)] = []
                var inRun = false

                for line in lines[lines.index(after: opened)...].prefix(while: { line in !line.hasPrefix("## ") }) {
                    if let name = named(line) {
                        if !inRun {
                            group += 1
                            inRun = true
                        }

                        listed.append((page: page, group: group, name: name))
                    } else if !line.isEmpty {
                        inRun = false
                    }
                }

                return listed
            }
    }

    private static func named(_ line: Substring) -> String? {
        guard line.hasPrefix("- `"), line.hasSuffix("`") else { return nil }

        return String(line.dropFirst("- `".count).dropLast())
    }
}

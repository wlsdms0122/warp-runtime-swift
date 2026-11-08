//
//  WARP.swift
//  WarpConformanceTests
//
//  Created by JSilver on 11/1/26.
//

import Foundation

// One WARP of the specification: a rule family, stated in its `SPEC.md` and
// measured by the cases in its `conformance/`. A runner reads its head and
// nothing past it, since the head is all that decides whether its cases are
// asked:
//
//     # WARP-<n>: <title>
//
//     Status: accepted
//     Supersedes: WARP-<a>, WARP-<b>
//
// `Supersedes` is the one optional line, and it says what this WARP replaces.
// What replaces this one is never written here, so it is not read here.
struct WARP: Sendable {
    enum Status: String, Sendable {
        case draft
        case accepted
    }

    // MARK: - Property
    static let prefix = "WARP-"

    let number: Int
    let title: String
    let status: Status

    // The WARPs this one replaces whole, by number, in the order written.
    let supersedes: [Int]

    let folder: URL

    var name: String { Self.name(of: number) }

    var specification: URL { folder.appendingPathComponent("SPEC.md") }

    var conformance: URL { folder.appendingPathComponent("conformance") }

    // MARK: - Initializer
    init(at folder: URL) throws {
        guard let number = Self.number(in: folder.lastPathComponent) else {
            throw ConformanceError("`\(folder.lastPathComponent)` is not a WARP's folder, which is named `WARP-<n>`")
        }

        let name = Self.name(of: number)
        let lines = try String(contentsOf: folder.appendingPathComponent("SPEC.md"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
        let heading = "# \(name): "

        guard let first = lines.first, first.hasPrefix(heading), first.count > heading.count else {
            throw ConformanceError("\(name)'s SPEC.md opens with `\(heading)<title>`")
        }

        guard
            lines.count > 2,
            lines[1].isEmpty,
            let written = Self.value(of: "Status", in: lines[2]),
            let status = Status(rawValue: written)
        else {
            throw ConformanceError("\(name)'s SPEC.md says `Status: draft` or `Status: accepted` after a blank line under its heading")
        }

        var supersedes: [Int] = []

        if lines.count > 3, lines[3].hasPrefix("Supersedes") {
            guard let written = Self.value(of: "Supersedes", in: lines[3]) else {
                throw ConformanceError("\(name)'s SPEC.md writes `Supersedes: WARP-<a>, WARP-<b>` or no such line")
            }

            for one in written.split(separator: ", ", omittingEmptySubsequences: false) {
                guard let superseded = Self.number(in: one) else {
                    throw ConformanceError("\(name) supersedes `\(one)`, which is not written `WARP-<n>`")
                }

                supersedes.append(superseded)
            }
        }

        self.number = number
        self.title = String(first.dropFirst(heading.count))
        self.status = status
        self.supersedes = supersedes
        self.folder = folder
    }

    // MARK: - Public
    static func name(of number: Int) -> String {
        "\(prefix)\(number)"
    }

    // The number a WARP's name carries, where the name is written the one way
    // a number writes it: no sign, and no zero in front of it.
    static func number(in name: some StringProtocol) -> Int? {
        guard
            name.hasPrefix(prefix),
            let number = Int(name.dropFirst(prefix.count)),
            number > 0,
            Self.name(of: number) == name
        else { return nil }

        return number
    }

    // The cases this WARP holds: the files named like cases in its
    // `conformance/`. A WARP without one holds none.
    func cases() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: conformance.path) else { return [] }

        return try FileManager.default
            .contentsOfDirectory(at: conformance, includingPropertiesForKeys: nil)
            .filter { file in file.lastPathComponent.hasSuffix(Case.suffix) }
    }

    // MARK: - Private
    private static func value(of key: String, in line: Substring) -> String? {
        let opening = "\(key): "

        guard line.hasPrefix(opening), line.count > opening.count else { return nil }

        return String(line.dropFirst(opening.count))
    }
}

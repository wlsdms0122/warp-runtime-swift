//
//  SeriesTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 11/1/26.
//

import Foundation
import Testing

// A runner finds what to ask by the specification's layout alone: each case
// in the `conformance/` of the one WARP it measures, and each WARP's head
// saying its number and status. A layout that has drifted is a case nobody
// asks, so this asks whether the layout holds.
@Suite("A runner reads the specification's layout")
struct SeriesTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every case sits in the conformance folder of one WARP, under a name no other case has")
    func everyCaseSitsInOneWARP() throws {
        // Given. Every file named like a case anywhere in the specification
        let files = try Self.files(under: Case.specification)
            .filter { path in path.hasSuffix(Case.suffix) }

        // When
        let astray = files.filter { path in
            let steps = path.split(separator: "/", omittingEmptySubsequences: false)

            return steps.count != 3 || WARP.number(in: steps[0]) == nil || steps[1] != "conformance"
        }
        let repeated = Dictionary(grouping: files) { path in path.split(separator: "/").last ?? "" }
            .filter { entry in entry.value.count > 1 }
            .map { entry in "'\(entry.key)' is in \(entry.value.sorted().joined(separator: " and "))" }
            .sorted()

        // Then
        #expect(!files.isEmpty)
        #expect(astray.isEmpty, "not in a WARP's conformance folder: \(astray.joined(separator: ", "))")
        #expect(repeated.isEmpty, "a name two cases share: \(repeated.joined(separator: ", "))")
    }

    @Test("every WARP opens with its own number and a status of draft or accepted")
    func everyWARPOpensWithItsHead() throws {
        // Given
        let folders = try Series.folders(in: Case.specification)

        // When
        let unread = folders.compactMap { folder -> String? in
            do {
                _ = try WARP(at: folder)

                return nil
            } catch {
                return "\(folder.lastPathComponent): \(error)"
            }
        }

        // Then
        #expect(!folders.isEmpty)
        #expect(unread.isEmpty, "a head that does not read: \(unread.joined(separator: "; "))")
    }

    // MARK: - Public
    // MARK: - Private
    // Every file under a folder, as its path from that folder.
    private static func files(under folder: URL) throws -> [String] {
        guard let walk = FileManager.default.enumerator(atPath: folder.path) else {
            throw ConformanceError("\(folder.path) cannot be walked")
        }

        return walk.compactMap { path in path as? String }.sorted()
    }
}

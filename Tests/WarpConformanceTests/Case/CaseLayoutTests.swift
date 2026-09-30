//
//  CaseLayoutTests.swift
//  WarpConformanceTests
//
//  Created by JSilver
//

import Foundation
import Testing
import Warp
import WarpSyntax

// Every case sits in the writer's layout, which is what makes a diff over
// `conformance/` show what changed rather than who indented it.
//
// A case is authored however its author likes, since the text reader takes any
// layout, and is run through the writer before it lands. That is a habit until
// something asks, so this asks.
@Suite("The cases are laid out by the writer")
struct CaseLayoutTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every case is the bytes the writer would write")
    func everyCaseIsWritersLayout() throws {
        var adrift: [String] = []

        for file in try Self.files() {
            let written = try String(contentsOf: file, encoding: .utf8)
            let laid = try TextEncoding().text(from: try TextEncoding().value(from: written)) + "\n"

            if written != laid { adrift.append(file.lastPathComponent) }
        }

        #expect(
            adrift.isEmpty,
            "not as the writer writes them: \(adrift.joined(separator: ", "))"
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func files() throws -> [URL] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Case
            .deletingLastPathComponent()   // WarpConformanceTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // warp-runtime-swift
            .deletingLastPathComponent()   // runtime
            .deletingLastPathComponent()   // the repository
            .appendingPathComponent("spec")
            .appendingPathComponent("conformance")

        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { file in file.lastPathComponent.hasSuffix(".test.warpt") }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }
    }
}

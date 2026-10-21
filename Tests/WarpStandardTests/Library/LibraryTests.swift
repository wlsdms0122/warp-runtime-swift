//
//  LibraryTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
@testable import Warp
import WarpSyntax
@testable import WarpStandard

// The documents of `lib/standard` are the source and what ships is a copy of them,
// so the two being the same bytes is what the copy is worth. A document edited
// without running `script/embed-library.sh` is caught here rather than by a
// runtime that quietly answers the old one.
@Suite("The vocabulary written in Warp")
struct LibraryTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("what ships is what lib/standard holds")
    func whatShipsIsWhatTheRepositoryHolds() throws {
        // Given
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Library
            .deletingLastPathComponent()   // WarpStandardTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // the repository
            .appendingPathComponent("warp")
            .appendingPathComponent("lib")
            .appendingPathComponent("standard")
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { file in file.pathExtension == "warpt" }

        // When / Then
        #expect(Set(files.map { file in file.deletingPathExtension().lastPathComponent })
            == Set(Library.documents.keys))

        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            let written = try String(contentsOf: file, encoding: .utf8)

            #expect(
                Library.documents[name] == written.trimmingCharacters(in: .newlines),
                "\(name).warpt differs from what ships. Run script/embed-library.sh"
            )
        }
    }

    @Test("every document of lib/standard reads")
    func everyDocumentReads() throws {
        // When
        for text in Library.documents.values {
            _ = try Loader().load(TextEncoding().value(from: text), identity: nil)
        }

        // Then. None was left out on the way in
        #expect(Module.library.count == Library.documents.count)
    }

    @Test("every procedure it declares is one this package does not")
    func itDeclaresWhatSwiftDoesNot() throws {
        // Given
        let written = Set(Module.library.values.flatMap(\.procedures.keys))

        // When / Then
        #expect(!written.isEmpty)
        #expect(written.intersection(Module.builtinProcedures).isEmpty)
    }

    // MARK: - Public
    // MARK: - Private
}

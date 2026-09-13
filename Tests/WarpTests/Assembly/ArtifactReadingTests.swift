//
//  ArtifactReadingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// What a reading of an artifact refuses.
//
// An artifact is this runtime's own writing, so what is asked here is what
// happens when the bytes are not that. Each case bends one field of a real
// artifact, because a writing built by hand would prove only that the reading
// refuses something it was never handed.
@Suite("An artifact whose writing is not one")
struct ArtifactReadingTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a count is written below zero")
    func aCountBelowZero() throws {
        // Given. A real artifact whose numbering opens at a number below zero.
        guard case var .array(parts) = try written(), case var .array(numbering) = parts[10] else {
            Issue.record("an artifact writes its numbering as a part")

            return
        }

        numbering[3] = .int(-1)
        parts[10] = .array(numbering)

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: .array(parts))
        }
    }

    @Test("is refused where a name keys two entries")
    func aNameWrittenTwice() throws {
        // Given. A real artifact whose declared types list repeats one entry.
        let written = try written()

        guard case var .array(parts) = written, case let .array(types) = parts[1], let first = types.first else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        parts[1] = .array(types + [first])

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: .array(parts))
        }
    }

    @Test("is refused where a part is written short")
    func aPartWrittenShort() throws {
        // Given. A real artifact with its last part dropped.
        guard case let .array(parts) = try written() else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: .array(parts.dropLast()))
        }
    }

    @Test("is refused where a part is written long")
    func aPartWrittenLong() throws {
        guard case let .array(parts) = try written() else {
            Issue.record("an artifact is written as a list of parts")

            return
        }

        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: .array(parts + [.null]))
        }
    }

    @Test("is refused where a numbering names one type twice")
    func aNumberingThatRepeats() throws {
        // Given. A real artifact whose type numbering lists one name twice. The
        // numbering answers by position, so a swallowed name moves every number
        // after it onto some other declaration.
        guard case var .array(parts) = try written(),
              case var .array(numbering) = parts[11],
              case let .array(types) = numbering[0],
              let first = types.first
        else {
            Issue.record("an artifact writes its type numbering as a part")

            return
        }

        numbering[0] = .array(types + [first])
        parts[11] = .array(numbering)

        // When / Then.
        #expect(throws: ArtifactRefused.self) {
            try Compiled(written: .array(parts))
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func written() throws -> Value {
        let sut = try Module(
            types: ["app.Point": .record(["x": .int, "y": .int])],
            procedures: [
                "app.entry": Procedure(
                    signature: Signature(parameters: ["p": Parameter(type: .any)], returns: .named("app.Point")),
                    body: [],
                    result: .cast(reference("p"), as: .named("app.Point"), optional: false)
                )
            ]
        )
        let compiled = try builder.compile([sut] + Module.standard)

        guard let mine = compiled.first(where: { one in one.declared.contains("app.entry") }) else {
            throw ConformanceMissing()
        }

        return try mine.written
    }
}

private struct ConformanceMissing: Error { }

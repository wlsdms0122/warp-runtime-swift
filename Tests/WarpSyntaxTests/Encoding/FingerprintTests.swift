//
//  FingerprintTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/16/26.
//

import Testing
import Warp
import WarpSyntax

// What a cache may key an artifact by.
//
// A fingerprint is taken of the whole artifact, and an artifact says which
// document it was compiled from, which Warp compiled it, and the fingerprints
// of what it leaned on. So the three things a key has to hold are held by one
// value, and these ask whether that is so: the same inputs answer alike, and
// the document or what it leans on moving moves the answer.
//
// The third is held from the other side. Which Warp wrote an artifact is a
// constant of the build running these, so what a second one answers cannot be
// asked here; what a reading does with an artifact another one wrote is asked
// where readings are refused.
@Suite("A fingerprint stands for everything an artifact was compiled from")
struct FingerprintTests {
    // MARK: - Property
    private let builder = Builder(fingerprinting: Fingerprint.of)

    private let program = try! Module(
        procedures: [
            "app.main": Procedure(
                signature: Signature(returns: .int),
                body: [],
                result: .call(Call(selector: "a.foo"))
            )
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("is the same twice for the same document behind the same artifact")
    func isTheSameTwice() async throws {
        // Given / When.
        let first = try await fingerprint(of: program, against: answering(.int(1)))
        let second = try await fingerprint(of: program, against: answering(.int(1)))

        // Then.
        #expect(first == second)
    }

    @Test("moves when the artifact behind it moves")
    func movesWithWhatItLeansOn() async throws {
        // Given. The same document, compiled against two artifacts that declare
        // the same procedure and answer differently.
        let first = try await fingerprint(of: program, against: answering(.int(1)))
        let second = try await fingerprint(of: program, against: answering(.int(2)))

        // Then. Nothing in this document changed, and what it is true against
        // did.
        #expect(first != second)
    }

    @Test("moves when the document moves")
    func movesWithTheDocument() async throws {
        // Given.
        let other = try Module(
            procedures: [
                "app.main": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .literal(.int(3))
                )
            ]
        )

        // When / Then.
        #expect(
            try await fingerprint(of: program, against: answering(.int(1)))
                != fingerprint(of: other, against: answering(.int(1)))
        )
    }

    // MARK: - Public
    // MARK: - Private
    private func answering(_ value: Value) -> Module {
        try! Module(
            procedures: [
                "a.foo": Procedure(signature: Signature(returns: .int), body: [], result: .literal(value))
            ]
        )
    }

    private func fingerprint(of module: Module, against used: Module) async throws -> Fingerprint {
        let behind = try await builder.compile([used])
        let compiled = try await builder.compile(
            [module],
            against: behind,
            supplying: Supplying([used, module])
        )

        return try #require(compiled[0].fingerprint)
    }
}

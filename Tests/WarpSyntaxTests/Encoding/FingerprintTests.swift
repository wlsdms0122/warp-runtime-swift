//
//  FingerprintTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax
import WarpTestSupport

// What a cache may key an object by.
//
// A fingerprint is taken of the whole object, and an object says which
// document it was compiled from, which Warp compiled it, and the fingerprints
// of what it leaned on. So the three things a key has to hold are held by one
// value, and these ask whether that is so: the same inputs give the same
// fingerprint, and the document or what it leans on moving moves it.
//
// The third is held from the other side. Which Warp wrote an object is a
// constant of the build running these, so what a second one gives cannot be
// asked here; what a reading does with an object another one wrote is asked
// where readings are refused.
@Suite("A fingerprint stands for everything an object was compiled from")
struct FingerprintTests {
    private struct ReturningQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .any) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let value: Value

        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            value
        }

        // MARK: - Private
    }

    // MARK: - Property
    private let builder = Builder(fingerprinting: Fingerprint.of)

    private let program = try! Module(
        procedures: [
            "App.main": Procedure(
                signature: Signature(returns: .int),
                body: [returning(.call(Call(selector: "A.foo", arguments: [.literal(.null)])))]
            )
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("is the same twice for the same document behind the same object")
    func isTheSameTwice() async throws {
        // Given / When
        let first = try await fingerprint(of: program, against: module(returning: .int(1)))
        let second = try await fingerprint(of: program, against: module(returning: .int(1)))

        // Then
        #expect(first == second)
    }

    @Test("moves when the object behind it moves")
    func movesWithWhatItLeansOn() async throws {
        // Given / When. The same document, compiled against two objects that
        // declare the same procedure and return different values.
        let first = try await fingerprint(of: program, against: module(returning: .int(1)))
        let second = try await fingerprint(of: program, against: module(returning: .int(2)))

        // Then. Nothing in this document changed, and what it is true against
        // did.
        #expect(first != second)
    }

    @Test("moves when the document moves")
    func movesWithTheDocument() async throws {
        // Given
        let other = try Module(
            procedures: [
                "App.main": Procedure(
                    signature: Signature(returns: .int),
                    body: [returning(.literal(.int(3)))]
                )
            ]
        )

        // When / Then
        #expect(
            try await fingerprint(of: program, against: module(returning: .int(1)))
                != fingerprint(of: other, against: module(returning: .int(1)))
        )
    }

    @Test("moves when a native procedure it uses declares itself differently")
    func movesWithANativeDeclaration() async throws {
        // Given / When. The same document, against a host procedure of one
        // spelling declared to return two different types. The declaration is
        // the native's document's, and that document's object is what this one
        // leans on.
        let first = try await fingerprint(of: program, against: native(declaring: .int))
        let second = try await fingerprint(of: program, against: native(declaring: .never))

        // Then
        #expect(first != second)
    }

    @Test("stays when a native procedure it uses returns differently under one declaration")
    func staysWithANativeReturnValue() async throws {
        // Given / When. Two hosts bringing one declaration with two bodies.
        // What a native procedure returns is the host's code, which no object
        // holds, so the key cannot see it: what tells two hosts apart is the
        // release the object is stamped with.
        let first = try await fingerprint(of: program, against: native(declaring: .int, returning: .int(1)))
        let second = try await fingerprint(of: program, against: native(declaring: .int, returning: .int(2)))

        // Then
        #expect(first == second)
    }

    // MARK: - Public
    // MARK: - Private
    private func native(declaring type: TypeExpression, returning value: Value = .int(1)) -> Module {
        try! Module(
            procedures: [
                "A.foo": Procedure(
                    signature: Signature(of: ReturningQuery.self, returns: type),
                    implementation: .query(ReturningQuery(value: value))
                )
            ]
        )
    }

    private func module(returning value: Value) -> Module {
        try! Module(
            procedures: [
                "A.foo": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .any)], returns: .int),
                    body: [returning(.literal(value))]
                )
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

        let stored = try #require(compiled[0].fingerprint)
        print("PROBE count=\(stored.bytes.count) stored=\(stored.rendered) behind=\(behind.map { $0.fingerprint?.rendered ?? "nil" })")
        return stored
    }
}

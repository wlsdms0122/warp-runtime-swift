//
//  FingerprintTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/16/26.
//

import Testing
import Warp
import WarpSyntax

// What a cache may key an object by.
//
// A fingerprint is taken of the whole object, and an object says which
// document it was compiled from, which Warp compiled it, and the fingerprints
// of what it leaned on. So the three things a key has to hold are held by one
// value, and these ask whether that is so: the same inputs answer alike, and
// the document or what it leans on moving moves the answer.
//
// The third is held from the other side. Which Warp wrote an object is a
// constant of the build running these, so what a second one answers cannot be
// asked here; what a reading does with an object another one wrote is asked
// where readings are refused.
@Suite("A fingerprint stands for everything an object was compiled from")
struct FingerprintTests {
    private struct AnsweringQuery: Query {
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
            "app.main": Procedure(
                signature: Signature(returns: .int),
                body: [],
                result: .call(Call(selector: "a.foo", arguments: [.literal(.null)]))
            )
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("is the same twice for the same document behind the same object")
    func isTheSameTwice() async throws {
        // Given / When.
        let first = try await fingerprint(of: program, against: answering(.int(1)))
        let second = try await fingerprint(of: program, against: answering(.int(1)))

        // Then.
        #expect(first == second)
    }

    @Test("moves when the object behind it moves")
    func movesWithWhatItLeansOn() async throws {
        // Given. The same document, compiled against two objects that declare
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

    @Test("moves when a native procedure it uses declares itself differently")
    func movesWithANativeDeclaration() async throws {
        // Given. The same document, against a host procedure of one spelling
        // declared to answer two different types. The declaration is the
        // native's document's, and that document's object is what this one
        // leans on.
        let first = try await fingerprint(of: program, against: native(returning: .int))
        let second = try await fingerprint(of: program, against: native(returning: .any))

        // Then.
        #expect(first != second)
    }

    @Test("stays when a native procedure it uses answers differently under one declaration")
    func staysWithANativeAnswer() async throws {
        // Given. Two hosts bringing one declaration with two bodies. What a
        // native answers is the host's code, which no object holds, so the
        // key cannot see it: what tells two hosts apart is the release the
        // object is stamped with.
        let first = try await fingerprint(of: program, against: native(returning: .int, answering: .int(1)))
        let second = try await fingerprint(of: program, against: native(returning: .int, answering: .int(2)))

        // Then.
        #expect(first == second)
    }

    // MARK: - Public
    // MARK: - Private
    private func native(returning type: TypeExpression, answering value: Value = .int(1)) -> Module {
        try! Module(
            procedures: [
                "a.foo": Procedure(
                    signature: Signature(of: AnsweringQuery.self, returns: type),
                    implementation: .query(AnsweringQuery(value: value))
                )
            ]
        )
    }

    private func answering(_ value: Value) -> Module {
        try! Module(
            procedures: [
                "a.foo": Procedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .any)], returns: .int),
                    body: [],
                    result: .literal(value)
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

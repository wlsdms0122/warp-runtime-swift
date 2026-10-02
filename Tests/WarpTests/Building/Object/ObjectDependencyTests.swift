//
//  ObjectDependencyTests.swift
//  WarpTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
@testable import Warp

// What an object says it was compiled against.
//
// A cache hands an object back for a document it has seen before, and what
// makes that answer right is that the object says what it leaned on. These
// hold it to saying exactly that: the objects it named, none it did not, and
// nothing at all where one of them cannot be named.
@Suite("An object records what it was compiled against")
struct ObjectDependencyTests {
    private struct PeekQuery: Query {
        typealias Parameters = NoParameters

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            .int(7)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // A stand-in for what a host works out from the bytes, which this package
    // does not write. Two objects that differ answer differently here, which
    // is all these ask of it.
    private let builder = Builder { value in Fingerprint(Array("\(value)".utf8)) }

    private var used: Module {
        get throws {
            try Module(
                procedures: [
                    "a.foo": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(1)))
                ]
            )
        }
    }

    private var unrelated: Module {
        get throws {
            try Module(
                procedures: [
                    "b.bar": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(2)))
                ]
            )
        }
    }

    private var program: Module {
        get throws {
            try Module(
                procedures: [
                    "app.main": Procedure(
                        signature: Signature(returns: .int),
                        body: [],
                        result: .call(Call(selector: "a.foo"))
                    )
                ]
            )
        }
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("names the object behind a procedure it calls")
    func namesWhatItCalls() async throws {
        // Given. The document it calls, compiled and worked out.
        let behind = try await builder.compile([used])

        // When
        let compiled = try await builder.compile(
            [program],
            against: behind,
            supplying: Supplying([used, program])
        )

        // Then
        #expect(compiled[0].dependencies == behind.compactMap(\.fingerprint))
    }

    @Test("says nothing about a document laid beside it that it never names")
    func saysNothingAboutTheUnnamed() async throws {
        // Given. Both laid down, and only one of them named.
        let behind = try await builder.compile([used, unrelated])

        // When
        let compiled = try await builder.compile(
            [program],
            against: behind,
            supplying: Supplying([used, unrelated, program])
        )

        // Then. The one it calls, and not the one standing beside it.
        let named = try #require(behind.first(where: { one in one.declared.contains("a.foo") }))

        #expect(compiled[0].dependencies == [try #require(named.fingerprint)])
    }

    @Test("has no writing where what it leaned on cannot be named")
    func hasNoWritingWithoutOne() async throws {
        // Given. A builder that works nothing out, so what it compiles stands
        // as an object with no fingerprint.
        let unknowing = Builder()
        let behind = try await unknowing.compile([used])

        #expect(behind[0].fingerprint == nil)

        // When
        let compiled = try await unknowing.compile(
            [program],
            against: behind,
            supplying: Supplying([used, program])
        )

        // Then. It leaned on something it cannot name, so it cannot be filed,
        // and saying so is not the same as saying it leaned on nothing.
        #expect(compiled[0].dependencies == nil)
        #expect(throws: ObjectUnwritable.self) { try compiled[0].object() }
    }

    @Test("tells a document written in Warp from one the host answers")
    func tellsTheTwoKindsApart() async throws {
        // Given. One declaration made twice: once as a body this language
        // lowers, once as a procedure the host answers. A host may build the
        // same thing either way.
        let lowered = try Module(
            procedures: [
                "box.peek": Procedure(signature: Signature(returns: .int), body: [], result: .literal(.int(7)))
            ]
        )
        let answered = try Module(
            procedures: [
                "box.peek": Procedure(signature: Signature(returns: .int), implementation: .query(PeekQuery()))
            ]
        )

        // When
        let asLowered = try await written(calling: "box.peek", behind: lowered)
        let asAnswered = try await written(calling: "box.peek", behind: answered)

        // Then. The two stand as different objects, and so does what calls
        // them.
        #expect(asLowered.behind != asAnswered.behind)
        #expect(asLowered.calling != asAnswered.calling)

        // And what carries that into the host is the record and nothing else.
        // The call is the same call either way: a body reaches a row by number
        // and the number does not move. So a host that kept no record of what
        // it leaned on would read one kind's object for the other's.
        let callingLowered = try #require(besideDependencies(asLowered.calling))

        #expect(callingLowered == besideDependencies(asAnswered.calling), "the host told the two kinds apart by itself")
    }

    // MARK: - Public
    // MARK: - Private
    // Everything an object says but what it leaned on.
    private func besideDependencies(_ value: Value) -> Value.Dictionary? {
        guard case let .dictionary(parts) = value else { return nil }

        return parts.removing(ObjectLayout.Key.dependencies.name)
    }

    private func written(
        calling selector: Name,
        behind vocabulary: Module
    ) async throws -> (behind: Value, calling: Value) {
        let caller = try Module(
            procedures: [
                "app.main": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: selector))
                )
            ]
        )
        let behind = try await builder.compile([vocabulary])
        let compiled = try await builder.compile(
            [caller],
            against: behind,
            supplying: Supplying([vocabulary, caller])
        )

        return (behind: try behind[0].object(), calling: try compiled[0].object())
    }
}

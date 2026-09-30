//
//  FoldingTests.swift
//  WarpTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

@Suite
struct FoldingTests {
    // MARK: - Property
    private let bindings: [Name: Value] = [
        "count": .int(3),
        "maybe": .null,
        "record": .dictionary(["a": .int(1)])
    ]
    private let sut: Folding

    // MARK: - Initializer
    init() async throws {
        sut = try await Builder().build(Module.standard).folding(bindings)
    }

    // MARK: - Test
    @Test("ref resolution preserves the type")
    func refResolutionPreservesType() async throws {
        // Given
        let reference: Path = [.key("count")]

        // When
        let value = try await sut.read(reference, at: .given("test"))

        // Then
        #expect(value == .int(3))
    }

    @Test("a null value flows through a ref untouched")
    func nullPassesThroughRef() async throws {
        // Given
        let reference: Path = [.key("maybe")]

        // When
        let value = try await sut.read(reference, at: .given("test"))

        // Then
        #expect(value == .null)
    }

    @Test("a null binding inside format spells null")
    func nullBindingInFormatSpellsNull() async throws {
        // Given. Null has a spelling of its own, the one it has inside a container
        let reference = interpolated(literal("amount="), spelling(reference("maybe")))

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .string("amount=null"))
    }

    @Test("a field nobody set reads as null where the author marked it")
    func absentPathReadsAsNull() async throws {
        // Given. The head of every reference is checked at load, so what is
        // left to be absent at run time is a field nobody set
        let reference: Path = [.key("record"), .key("gone", optional: true)]

        // When / Then
        #expect(try await sut.read(reference, at: .given("test")) == .null)
    }

    @Test("a type-misusing path throws ReferenceUnfit")
    func shapeMisuseThrowsUnfit() async {
        // Given
        let reference: Path = [.key("count"), .key("field")]

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await sut.read(reference, at: .given("test"))
        }
    }

    @Test("nested structure resolves element by element")
    func nestedStructureResolves() async throws {
        // Given
        let reference = Expression.record([
            "n": .reference([.key("count")]),
            "list": .array([.literal(.string("x"))])
        ])

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .dictionary(["n": .int(3), "list": .array([.string("x")])]))
    }

    @Test("format renders over its declared with bindings")
    func declaredBindingsRenderFormat() async throws {
        // Given
        let reference = interpolated(literal("n="), spelling(reference("count")))

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .string("n=3"))
    }

    @Test("in a closed scope a binding named after an ambient head is just a binding")
    func closedScopeServesBindingNamedAfterAmbientHead() async throws {
        // Given. A closed surface has no reserved heads: a binding named `run`
        // is just a binding, not the ambient namespace of that name
        let reference = interpolated(literal("who="), spelling(reference("count")))

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .string("who=3"))
    }

    @Test("a quoted payload passes verbatim, unevaluated")
    func quotedPayloadPassesVerbatim() async throws {
        // Given. The payload is data: a ref-shaped record inside stays a record
        let reference = Expression.literal(.dictionary([
            "ref": .string("count"),
            "note": .string("${count}")
        ]))

        // When
        let value = try await read(reference)

        // Then. Nothing evaluated, nothing rendered
        #expect(value == .dictionary([
            "ref": .string("count"),
            "note": .string("${count}")
        ]))
    }

    // MARK: - Public
    // MARK: - Private
    // An expression other than a path is read by a run, the bindings handed
    // over as arguments.
    private func read(_ expression: Warp.Expression) async throws -> Value? {
        try await answer(
            of: [],
            result: expression,
            arguments: bindings,
            signature: Signature(parameters: bindings.keys.sorted().map { name in Parameter(name: name, type: .any) })
        )
    }
}

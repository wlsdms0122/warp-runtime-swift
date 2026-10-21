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
import WarpTestSupport

@Suite("Reading a reference at the build")
struct FoldingTests {
    // MARK: - Property
    private let bindings: [Name: Value] = [
        "count": .int(3),
        "maybe": .null,
        "struct": .dictionary(["a": .int(1)])
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
        let reference: Path = [.name("count")]

        // When
        let value = try await sut.read(reference.lowered, at: .given("test"))

        // Then
        #expect(value == .int(3))
    }

    @Test("a null value flows through a ref untouched")
    func nullPassesThroughRef() async throws {
        // Given
        let reference: Path = [.name("maybe")]

        // When
        let value = try await sut.read(reference.lowered, at: .given("test"))

        // Then
        #expect(value == .null)
    }

    @Test("a null binding inside a template spells null")
    func nullBindingInATemplateSpellsNull() async throws {
        // Given. Null has a spelling of its own, the one it has inside a container
        let reference = interpolated(literal("amount="), spelling(reference("maybe")))

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .string("amount=null"))
    }

    @Test("an entry nobody set reads as null where the author marked it")
    func absentPathReadsAsNull() async throws {
        // Given. The head of every reference is checked at load, so what is
        // left to be absent at run time is an entry nobody set
        let reference: Path = [.name("struct"), .index("gone", optional: true)]

        // When / Then
        #expect(try await sut.read(reference.lowered, at: .given("test")) == .null)
    }

    @Test("a type-misusing path throws ReferenceUnfit")
    func typeMisuseThrowsUnfit() async {
        // Given
        let reference: Path = [.name("count"), .name("field")]

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await sut.read(reference.lowered, at: .given("test"))
        }
    }

    @Test("nested structure resolves element by element")
    func nestedStructureResolves() async throws {
        // Given
        let reference = map([
            "n": .reference([.name("count")]),
            "list": .array([.literal(.string("x"))])
        ])

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .dictionary(["n": .int(3), "list": .array([.string("x")])]))
    }

    @Test("a template renders over the names it reads")
    func aTemplateRendersOverItsNames() async throws {
        // Given
        let reference = interpolated(literal("n="), spelling(reference("count")))

        // When
        let value = try await read(reference)

        // Then
        #expect(value == .string("n=3"))
    }

    @Test("a quoted payload passes verbatim, unevaluated")
    func quotedPayloadPassesVerbatim() async throws {
        // Given. The payload is data: a ref-shaped map inside stays a map
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
            returning: expression,
            arguments: bindings,
            signature: Signature(parameters: bindings.keys.sorted().map { name in Parameter(name: name, type: .any) }, returns: .any)
        )
    }
}

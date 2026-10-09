//
//  SignatureTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpStandard
import WarpTestSupport

@Suite("How a document spells a signature")
struct SignatureTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a parameter written without a type declares nothing, and takes anything")
    func untypedParameterDeclaresNothing() throws {
        // Given / When. `Any` would say every type is welcome; this says nothing
        // at all, and the two are not the same declaration even though neither
        // is checked
        let sut = try Loader.testing.loadDocument([
            "procedures": [
                "keep": [
                    "parameters": [["name": "labelled", "type": "Any"], ["name": "subject"]],
                    "body": [["let": "done", "value": ["ref": "subject"]]]
                ]
            ]
        ])

        // Then
        let signature = try #require(sut.procedures["keep"]).signature

        #expect(signature.parameter(named: "subject")?.type == nil)
        #expect(signature.parameter(named: "labelled")?.type == .any)

        // And. Neither checks, so both take a type nothing was said about.
        let settled = try settled(signature, given: ["subject": .int(1), "labelled": .int(2)])

        #expect(settled["subject"] == .int(1))
        #expect(settled["labelled"] == .int(2))
    }

    @Test("a procedure written without a return type declares nothing")
    func untypedReturnDeclaresNothing() throws {
        // Given / When
        let sut = try Loader.testing.loadDocument([
            "procedures": [
                "quiet": ["body": [["let": "done", "value": "end"]]],
                "loud": ["returns": "Any", "body": [["let": "done", "value": "end"]]]
            ]
        ])

        // Then
        #expect(try #require(sut.procedures["quiet"]).signature.returns == nil)
        #expect(try #require(sut.procedures["loud"]).signature.returns == .any)
    }

    @Test("a missing required input is rejected")
    func missingRequiredInputRejected() {
        // Given
        let sut = Signature(parameters: [Parameter(name: "name", type: .string)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: [:])
        }
    }

    @Test("a type mismatch is rejected")
    func typeMismatchRejected() {
        // Given
        let sut = Signature(parameters: [Parameter(name: "count", type: .int)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["count": .string("three")])
        }
    }

    @Test("a fraction is not a whole number, whatever it is worth")
    func aFractionDoesNotNarrow() throws {
        // Given. A slot asking for a whole number. Taking a fraction that
        // happened to be whole would make the answer to "does this fit" depend
        // on the value rather than the type: `3.0` accepted where `3.5` is
        // refused, by a declaration that names neither.
        let sut = Signature(parameters: [Parameter(name: "count", type: .int)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["count": .double(3)])
        }

        // And a whole number is no fraction either
        let ratio = Signature(parameters: [Parameter(name: "ratio", type: .double)])

        #expect(throws: ArgumentError.self) {
            try settled(ratio, given: ["ratio": .int(3)])
        }
    }

    @Test("an undeclared input name is rejected")
    func undeclaredInputRejected() {
        // Given
        let sut = Signature(parameters: [Parameter(name: "a", type: .string)])

        // When / Then. An extra name is a typo surfaced, not a value smuggled
        // in
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["a": .string("x"), "sneaky": .int(9)])
        }
    }

    @Test("no inputs declaration is still a closed contract, and strays are rejected")
    func strayInputRejectedOnEmptySignature() async throws {
        // Given. Absent `inputs:` is an empty signature, not an absent contract
        let spec = try Loader.testing.loadProcedure(["body": [["let": "noop", "value": "ok"]]])

        // When / Then
        await #expect(throws: ArgumentError.self) {
            try await run(spec, arguments: ["stray": .string("leaked")])
        }
    }

    @Test("every parameter is given, and one declaring null takes null")
    func everyParameterIsGiven() throws {
        // Given
        let sut = try #require(try Loader.testing.loadProcedure([
            "parameters": [["name": "dir", "type": "String?"], ["name": "file", "type": "String"]],
            "body": [["let": "seen", "value": ["ref": "dir"]]]
        ]).procedures[entryName]?.signature)

        // When / Then
        #expect(try settled(sut, given: ["dir": .null, "file": "a"]) == ["dir": .null, "file": "a"])
        #expect {
            try settled(sut, given: ["file": "a"])
        } throws: { error in
            "\(error)".contains("was given nothing for 'dir'")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The boundary over no table, answered by name.
    private func settled(_ signature: Signature, given: [Name: Value]) throws -> [Name: Value] {
        let slots = signature.lowered(in: .empty)
        let settled = try signature.settle(given, over: slots, as: "entry '\(entryName)'", in: .empty)

        return settled.enumerated().reduce(into: [Name: Value]()) { named, entry in
            named[slots[entry.offset].name] = entry.element
        }
    }
}

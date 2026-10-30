//
//  ExpressionFormTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax
import WarpTestSupport

@Suite("How a document spells an expression")
struct ExpressionFormTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a String spelling a placeholder stays a literal")
    func placeholderStringStaysLiteral() throws {
        // Given / When. The injection doctrine: no string is ever re-parsed
        // into a ref
        let reference = try read(ExpressionReader.self, from: "${secret}").expression

        // Then
        guard case let .literal(.string(string)) = reference else {
            Issue.record("expected stringValue, got \(reference)")

            return
        }

        #expect(string == "${secret}")
        #expect(validates(reference))
    }

    @Test("a value the document named is data, and keeps the name")
    func aNamedStructStaysALiteral() throws {
        // Given. A struct standing under a name is a value of that type, not a
        // mapping read by its tag
        let written = try Value.holding([(name: "amount", value: .int(7))], named: "bank.Money")

        // When
        let expression = try read(ExpressionReader.self, from: written).expression

        // Then
        guard case let .literal(carried) = expression else {
            Issue.record("expected a literal, got \(expression)")

            return
        }

        #expect(carried == written)
    }

    @Test("a bytes value decodes as a bytes literal, and numbers stay numbers")
    func bytesDecodeAsBytes() throws {
        // Given / When. Bytes, the one binary spelling, cross the Value
        // bridge whole; an array of small numbers next to it stays an array of
        // numbers
        let bytes = try read(ExpressionReader.self, from: .bytes([0x6A, 0x73])).expression
        let numbers = try read(ExpressionReader.self, from: .array([.int(1), .int(2)])).expression

        // Then
        guard case let .literal(carried) = bytes else {
            Issue.record("expected a bytes literal, got \(bytes)")

            return
        }

        #expect(carried == .bytes([0x6A, 0x73]))

        guard case .array = numbers else {
            Issue.record("expected an array of numbers, got \(numbers)")

            return
        }
    }

    @Test("only the exact { ref: } form decodes as a reference")
    func exactRefFormDecodes() throws {
        // Given / When
        let reference = try read(ExpressionReader.self, from: ["ref": "items[0].name"]).expression

        // Then
        #expect(reference.referencePath == [.name("items"), .index(0), .name("name")])
    }

    @Test("a struct's field named like a tag is a field, and reaches nothing")
    func aFieldNamedLikeATagStaysInert() throws {
        // Given / When. Under `struct`, a field's name is never a key the
        // grammar reads, so a field called `ref` holds the string it was given
        let reference = try read(ExpressionReader.self, from: ["struct": ["ref": "secret", "value": 1]]).expression

        // Then
        guard case let .struct(fields) = reference else {
            Issue.record("expected a struct, got \(reference)")

            return
        }

        #expect(fields["ref"]?.constantValue == .string("secret"))
        #expect(fields["value"]?.constantValue == .int(1))
        #expect(validates(reference), "a field named `ref` names nothing to resolve")
    }

    @Test("a half-spelled form mapping is rejected at load", arguments: [
        ["ref": "a", "extra": "b"] as Value,
        ["ref": 3],
        ["struct": ["a": 1], "extra": "b"],
        ["struct": "a"],
        ["as": "Int"]
    ])
    func ambiguousFormStructRejected(fixture: Value) {
        // When / Then. A half-spelled form is an author mistake, not a struct;
        // plain data carrying these keys is written under `struct`
        #expect(throws: ReadingError.self) {
            _ = try read(ExpressionReader.self, from: fixture).expression
        }
    }

    @Test("a struct is written under `struct`, and each field is an expression")
    func aStructIsWrittenUnderItsTag() throws {
        // Given / When
        let reference = try read(ExpressionReader.self, from: ["struct": ["name": "report", "target": ["ref": "target"]]]).expression

        // Then
        guard case let .struct(literal) = reference else {
            Issue.record("expected structValue, got \(reference)")

            return
        }

        #expect(literal["target"]?.referencePath == [.name("target")])
    }

    @Test("a bare mapping where a value is wanted is refused")
    func aBareMappingIsRefused() {
        // Given. A mapping is an expression by its one tag, and these fields
        // carry none
        let fixture: Value = ["name": "report", "target": ["ref": "target"]]

        // When / Then
        #expect {
            try read(ExpressionReader.self, from: fixture).expression
        } throws: { error in
            "\(error)".contains("a mapping where a value is wanted is one of")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

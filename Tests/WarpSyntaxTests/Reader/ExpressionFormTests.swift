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

@Suite
struct ExpressionFormTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a string spelling a placeholder stays a literal")
    func placeholderStringStaysLiteral() throws {
        // Given. The injection doctrine: no string is ever re-parsed into a ref
        let reference = try loader.expression(from: "${secret}")

        // Then
        guard case let .literal(.string(string)) = reference else {
            Issue.record("expected stringValue, got \(reference)")

            return
        }

        #expect(string == "${secret}")
        #expect(validates(reference))
    }

    @Test("a value the document named is data, and keeps the name")
    func aNamedRecordStaysALiteral() throws {
        // Given. A record standing under a name is a value of that type, not a
        // mapping read by its tag
        let written = try TextEncoding().value(from: "warpt 1\nbank.Money { amount 7 }\n")

        // When
        let read = try loader.expression(from: written)

        // Then
        guard case let .literal(carried) = read else {
            Issue.record("expected a literal, got \(read)")

            return
        }

        #expect(carried == written)
    }

    @Test("a bytes value decodes as a bytes literal, and numbers stay numbers")
    func bytesDecodeAsBytes() throws {
        // Given. The one binary kind crosses the Value bridge whole; an array
        // of small numbers next to it must stay an array of numbers
        let bytes = try loader.expression(from: .bytes([0x6A, 0x73]))
        let numbers = try loader.expression(from: .array([.int(1), .int(2)]))

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
        // Given
        let reference = try loader.expression(from: ["ref": "items[0].name"])

        // Then
        #expect(reference.referencePath == [.key("items"), .index(0), .key("name")])
    }

    @Test("a record's field named like a tag is a field, and reaches nothing")
    func aFieldNamedLikeATagStaysInert() throws {
        // Given. Under `record`, a field's name is never a key the grammar
        // reads, so a field called `ref` holds the text it was given
        let reference = try loader.expression(from: ["record": ["ref": "secret", "value": 1]])

        // Then
        guard case let .record(fields) = reference else {
            Issue.record("expected a record, got \(reference)")

            return
        }

        #expect(fields["ref"]?.constantValue == .string("secret"))
        #expect(fields["value"]?.constantValue == .int(1))
        #expect(validates(reference), "a field named `ref` names nothing to resolve")
    }

    @Test("a half-spelled form record is rejected at load", arguments: [
        ["ref": "a", "extra": "b"] as Value,
        ["ref": 3],
        ["record": ["a": 1], "extra": "b"],
        ["record": "a"],
        ["as": "int"],
        ["with": ["a": 1]],
        ["format": "x", "extra": "b"],
        ["format": "x", "with": [1, 2]],
        ["format": ["a"], "with": ["a": 1]]
    ])
    func ambiguousFormRecordRejected(fixture: Value) {
        // When / Then. A half-spelled form is an author mistake, not a record;
        // plain data carrying these keys is written under `record`
        #expect(throws: ReadingError.self) {
            _ = try loader.expression(from: fixture)
        }
    }

    @Test("a placeholder undeclared in `with` is rejected")
    func undeclaredPlaceholderRejected() {
        // Given. The format surface is closed over its `with` bindings
        let fixture: Value = [
            "format": "hello, ${who} from ${where}",
            "with": ["who": ["ref": "who"]]
        ]

        // When / Then
        #expect(throws: ReadingError.self) {
            _ = try loader.expression(from: fixture)
        }
    }

    @Test("a closed format template decodes")
    func closedFormatDecodes() throws {
        // Given
        let reference = try loader.expression(from: [
            "format": "hello, ${who}",
            "with": ["who": ["ref": "who"]]
        ], in: .testing)

        // Then. Outward references are the binding expressions, never the
        // template
        #expect(validates(reference, visible: ["who"]))
        #expect(!validates(reference), "the binding expression reaches outward")
    }

    @Test("a template lowers to the procedures that build it")
    func templateLowersToProcedures() throws {
        // Given
        let reference = try loader.expression(from: [
            "format": "hello, ${who}",
            "with": ["who": ["ref": "name"]]
        ], in: .testing)

        // Then. Nothing in the language knows what a template is: what is left
        // is an array written one after another, each value asked how it reads
        guard
            case let .call(joined) = reference,
            case let .array(pieces) = joined.arguments.first
        else {
            Issue.record("expected a joined array, got \(reference)")

            return
        }

        #expect(joined.selector == Notation.testing.interpolation?.joined)
        #expect(pieces.count == 2)
        #expect(pieces.first?.constantValue == .string("hello, "))

        guard case let .call(spelled)? = pieces.last else {
            Issue.record("expected the placeholder to ask how its value reads")

            return
        }

        // The binding is substituted, so the placeholder never names anything
        // the template was not given.
        #expect(spelled.selector == Notation.testing.interpolation?.read)
        #expect(spelled.arguments.first?.referencePath == [.key("name")])
    }

    @Test("an index reference inside a placeholder stays inside the template")
    func indexReferenceStaysClosed() throws {
        // Given. `${xs[i]}` names two bindings, and `validateClosed` makes the
        // author declare both. What is built must read both from the template
        let reference = try loader.expression(from: [
            "format": "at ${xs[i]}",
            "with": ["xs": ["ref": "items"], "i": ["ref": "cursor"]]
        ], in: .testing)

        // Then. The index must have been substituted too, or it resolves
        // against whatever scope the statement runs in
        guard
            case let .call(joined) = reference,
            case let .array(pieces) = joined.arguments.first,
            case let .call(spelled)? = pieces.last,
            case let .reference(path)? = spelled.arguments.first
        else {
            Issue.record("expected a spelled reference, got \(reference)")

            return
        }

        #expect(path == [.key("items"), .indexRef([.key("cursor")])])
    }

    @Test("a placeholder drilling into a computed binding is refused")
    func drillingIntoAComputedBindingIsRefused() {
        // Given / When / Then. Continuing a path needs a path to continue, and
        // reading the placeholder as written would reach the ambient scope
        #expect(throws: (any Error).self) {
            try loader.expression(from: [
                "format": "hello, ${who.name}",
                "with": ["who": ["record": ["name": "warp"]]]
            ])
        }
    }

    @Test("a record is written under `record`, and each field is an expression")
    func aRecordIsWrittenUnderItsTag() throws {
        // Given
        let reference = try loader.expression(from: ["record": ["name": "report", "target": ["ref": "target"]]])

        // Then
        guard case let .record(record) = reference else {
            Issue.record("expected recordValue, got \(reference)")

            return
        }

        #expect(record["target"]?.referencePath == [.key("target")])
    }

    @Test("a bare mapping where a value is wanted is refused")
    func aBareMappingIsRefused() {
        // Given. A mapping is an expression by its one tag, and these fields
        // carry none
        let fixture: Value = ["name": "report", "target": ["ref": "target"]]

        // When / Then
        #expect {
            try loader.expression(from: fixture)
        } throws: { error in
            "\(error)".contains("a mapping where a value is wanted is one of")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

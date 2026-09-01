//
//  UnwritableTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// The shapes a document has no way to say.
//
// All of them are built rather than parsed — a document could not make one, so
// nothing here comes back from a reader. They are reachable because assembling
// the language's shapes directly is a supported way to write a program, and
// writing one out is what this whole direction exists for. What matters is that
// each is refused: a document that came back meaning something else would be
// worse than no document, because nothing downstream could tell.
@Suite("A program shape with no document is refused rather than approximated")
struct UnwritableTests {
    // MARK: - Property
    private let sut = Writer()
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure held as a value is not data")
    func aProcedureValueIsNotData() {
        // Given — a closure has already taken a scope with it, and a document
        // carries neither code nor the scope it closed over
        let held = Value.procedure(
            Closure(procedure: Procedure(body: []), captured: Scope())
        )

        // When / Then
        #expect {
            try sut.value(of: module(binding: .literal(held)))
        } throws: { error in
            "\(error)".contains("not data")
        }

        // And no deeper in either — a list of them is no more writable
        #expect(throws: WritingError.self) {
            try sut.value(of: module(binding: .literal(.array([held]))))
        }
    }

    @Test("a record whose fields are read as a form has no document")
    func aRecordThatWouldReadAsAFormIsRefused() {
        // Given — a record of expressions cannot be quoted, because `{ value: }`
        // says the fields are data rather than things to work out
        let sut = try? sut.value(
            of: module(binding: .record(["ref": .literal(.string("not-a-path"))]))
        )

        // Then
        #expect(sut == nil)
    }

    @Test("a declared type named like a built-in has no document")
    func aTypeNamedLikeABuiltinIsRefused() {
        // Given — nothing stops a module declaring a type called `int`; a
        // document just reads the name it knows as the type it knows
        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.named("int"))
        }

        #expect(throws: Never.self) {
            try sut.value(of: TypeExpression.named("Task"))
        }
    }

    @Test("a nullable writes its trailing ?, and one with no spelling inside has no document")
    func aNullableSpellsOrRefuses() throws {
        // Given — the trailing `?` needs a name in front of it, and a record
        // spells as a mapping rather than a name
        #expect(try sut.value(of: TypeExpression.nullable(.int)) == .string("int?"))
        #expect(
            try sut.value(of: TypeExpression.nullable(.array(.string)))
                == .string("array<string>?")
        )

        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.nullable(.record(["id": .string])))
        }
    }

    @Test("a range bounded by a fraction with no spelling has no document")
    func aRangeWithAnUnspellableBoundIsRefused() throws {
        // Given — the bounds are the whole of what a range is written as, so a
        // bound with no spelling leaves nothing to write. The language admits
        // an infinity on purpose — it orders like any other bound — and what a
        // message shows it in reads back as an error rather than as the range.
        #expect(
            try sut.value(of: TypeExpression.ranged(.whole(from: 0, to: .through(255))))
                == .string("int(0...255)")
        )
        #expect(
            try sut.value(of: TypeExpression.ranged(.fraction(from: 0)))
                == .string("double(0.0...)")
        )

        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.ranged(.fraction(from: 0, to: .through(.infinity))))
        }

        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.ranged(.fraction(to: .through(.nan))))
        }
    }

    @Test("a record type shaped like a procedure type has no document")
    func aRecordTypeThatWouldReadAsAProcedureIsRefused() {
        // Given — a record and a procedure are both written as a mapping, and
        // the key that tells them apart is the procedure's
        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.record(["procedure": .int]))
        }

        // Two fields cannot be mistaken for one — the procedure form is a single
        // key, so this stays a record
        #expect(throws: Never.self) {
            try sut.value(of: TypeExpression.record(["procedure": .int, "other": .bool]))
        }
    }

    // MARK: - Public
    // MARK: - Private
    // One statement around whatever is under test, since none of these shapes
    // can be reached by writing a document.
    private func module(binding expression: Warp.Expression) throws -> Module {
        try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["word": Parameter(type: .string)]),
                    body: [Statement(id: "probe", expression: expression)]
                )
            ]
        )
    }
}

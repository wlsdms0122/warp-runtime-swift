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
import WarpTestSupport

// The pieces a document has no way to say.
//
// All of them are built rather than parsed. A document could not make one, so
// nothing here comes back from a reader. They are reachable because assembling
// the language's types directly is a supported way to write a program, and
// writing one out is what this whole direction exists for. What matters is that
// each is refused: a document that came back meaning something else would be
// worse than no document, because nothing downstream could tell.
@Suite("A piece of a program with no document is refused rather than approximated")
struct UnwritableTests {
    // MARK: - Property
    private let sut = Writer()
    private let loader = Loader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure held as a value is not data")
    func aProcedureValueIsNotData() async throws {
        // Given. A closure has already taken a scope with it, and a document
        // carries neither code nor the scope it closed over
        let held = try await procedureValue()

        // When / Then. A program carrying one never reaches a writing: making a
        // module is checking one, and this is one of the things it is not
        #expect {
            try module(binding: .literal(held))
        } throws: { error in
            "\(error)".contains("not data")
        }

        // And no deeper in either. A list of them is no more a program
        #expect(throws: ValidationError.self) {
            try module(binding: .literal(.array([held])))
        }

        // What a writing still turns away is one handed straight to it, which
        // is its own boundary rather than a program's
        #expect(throws: EncodingRefused.self) {
            try BinaryEncoding().data(from: held)
        }
    }

    @Test("a declared type named like a built-in has no document")
    func aTypeNamedLikeABuiltinIsRefused() {
        // When / Then. A document reads the name it knows as the type it
        // knows
        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.named("Int"))
        }

        #expect(throws: Never.self) {
            try sut.value(of: TypeExpression.named("Task"))
        }
    }

    @Test(
        "a type whose spelling the reading refuses, or reads as another type, has no document",
        arguments: [
            TypeExpression.optional(.variable(.int)),
            .composition(["App.A"]),
            .named("Array<Int>"),
            .array(.named("Int"))
        ]
    )
    func aSpellingThatDoesNotReadBackIsRefused(type: TypeExpression) {
        // When / Then
        #expect(throws: WritingError.self) {
            try sut.value(of: type)
        }
    }

    @Test("a composition's names are written in name order")
    func aCompositionIsWrittenInItsOneSpelling() throws {
        // When / Then
        #expect(try sut.value(of: TypeExpression.composition(["App.B", "App.A"])) == .string("App.A & App.B"))
    }

    @Test("an Optional writes its trailing ?, after parentheses around a procedure type")
    func anOptionalSpells() throws {
        // When / Then. A `?` after a procedure type's return type would be the
        // return type's, so the whole procedure is written in parentheses before
        // it
        #expect(try sut.value(of: TypeExpression.optional(.int)) == .string("Int?"))
        #expect(
            try sut.value(of: TypeExpression.optional(.array(.string)))
                == .string("Array<String>?")
        )
        #expect(
            try sut.value(of: TypeExpression.optional(.procedure(ProcedureType(returns: .int, failing: .anything))))
                == .string("(() throws -> Int)?")
        )
        #expect(try sut.value(of: TypeExpression.optional(.procedure(nil, .const))) == .string("(const Procedure)?"))
        #expect(try sut.value(of: TypeExpression.optional(.procedure(nil))) == .string("Procedure?"))
    }

    @Test("a struct applied to types writes them between its brackets")
    func aStructAppliedToTypesSpells() throws {
        // When / Then
        #expect(
            try sut.value(of: TypeExpression.named("App.Box", arguments: [.int, .parameter(name: "T")]))
                == .string("App.Box<Int, some T>")
        )
        #expect(
            try sut.value(of: TypeExpression.named("App.Box", arguments: [.procedure(ProcedureType(returns: .int, failing: .anything))]))
                == .string("App.Box<() throws -> Int>")
        )
    }

    @Test("a path holding a name no path spells has no document")
    func aPathWithAnUnspellableNameIsRefused() throws {
        // Given. A name holding a dot or a bracket is one segment to the
        // program and something else to a document
        let dotted = Path([.name("a.b")])
        let bracketed = Path([.name("a"), .name("[0")])

        // When / Then. Neither as a reference nor as the path a `set` writes
        #expect(throws: WritingError.self) { try sut.value(of: Warp.Expression.reference(dotted)) }
        #expect(throws: WritingError.self) { try sut.value(of: Warp.Expression.reference(bracketed)) }
        #expect(throws: WritingError.self) {
            try sut.value(of: Statement(binding: .assignment(dotted), expression: .literal(.int(1))))
        }

        #expect(
            try sut.value(of: Warp.Expression.reference([.name("a"), .index(0, optional: true), .indexRef([.name("i")])]))
                == .dictionary(["ref": .string("a?[0][i]")])
        )
    }

    // MARK: - Public
    // MARK: - Private
    // One statement around whatever is under test, since none of these pieces
    // can be reached by writing a document.
    private func module(binding expression: Warp.Expression) throws -> Module {
        try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "procedure", type: .string)]),
                    body: [Statement(binding: .constant("probe"), expression: expression)]
                )
            ]
        )
    }
}

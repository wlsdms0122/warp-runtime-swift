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
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure held as a value is not data")
    func aProcedureValueIsNotData() throws {
        // Given. A closure has already taken a scope with it, and a document
        // carries neither code nor the scope it closed over
        let held = Value.procedure(
            Closure.assembled()
        )

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
        #expect(throws: (any Error).self) {
            try BinaryEncoding().data(from: held)
        }
    }

    @Test("a declared type named like a built-in has no document")
    func aTypeNamedLikeABuiltinIsRefused() {
        // When / Then. Nothing stops a module declaring a type called `Int`; a
        // document just reads the name it knows as the type it knows
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
            TypeExpression.nullable(.composition(["App.A", "App.B"])),
            .nullable(.nullable(.int)),
            .nullable(.any),
            .nullable(.parameter(name: "T")),
            .nullable(.variable(.int)),
            .composition(["Foo", "Int"]),
            .composition(["Foo", "Array<Int>"]),
            .parameter(name: "a.b"),
            .parameter(name: "a<b>"),
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

    @Test("a procedure whose parameter type has no spelling has no document, though it builds")
    func aBuiltParameterTypeWithNoSpellingIsRefused() async throws {
        // Given. Two contracts that each ask one procedure, and a slot taking
        // either or null
        let module = try Module(
            contracts: [
                "App.A": ["a": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .int)],
                "App.B": ["b": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .int)]
            ],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "either", type: .nullable(.composition(["App.A", "App.B"])))]
                    ),
                    body: [],
                    result: .literal(.null)
                )
            ]
        )

        // When
        await #expect(throws: Never.self) { try await Builder().build([module] + Module.standard) }

        // Then
        #expect(throws: WritingError.self) {
            try sut.value(of: module)
        }
    }

    @Test("one name composing is written as the name, and names in any order are written in name order")
    func aCompositionIsWrittenInItsOneSpelling() throws {
        // When / Then
        #expect(try sut.value(of: TypeExpression.composition(["App.A"])) == .string("App.A"))
        #expect(try sut.value(of: TypeExpression.array(.composition(["App.A"]))) == .string("Array<App.A>"))
        #expect(try sut.value(of: TypeExpression.composition(["App.B", "App.A"])) == .string("App.A & App.B"))
    }

    @Test("a nullable writes its trailing ?, and one with no spelling inside has no document")
    func aNullableSpellsOrRefuses() throws {
        // When / Then. The trailing `?` needs a name in front of it, and a
        // record spells as a mapping rather than a name
        #expect(try sut.value(of: TypeExpression.nullable(.int)) == .string("Int?"))
        #expect(
            try sut.value(of: TypeExpression.nullable(.array(.string)))
                == .string("Array<String>?")
        )

        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.nullable(.record(["id": .string])))
        }
    }

    @Test("a path holding a name no path spells has no document")
    func aPathWithAnUnspellableNameIsRefused() throws {
        // Given. A name holding a dot or a bracket is one segment to the
        // program and something else to a document
        let dotted = Path([.key("a.b")])
        let bracketed = Path([.key("a"), .key("[0")])

        // When / Then. Neither as a reference nor as the path a `set` writes
        #expect(throws: WritingError.self) { try sut.value(of: Warp.Expression.reference(dotted)) }
        #expect(throws: WritingError.self) { try sut.value(of: Warp.Expression.reference(bracketed)) }
        #expect(throws: WritingError.self) {
            try sut.value(of: Statement(binding: .assignment(dotted), expression: .literal(.int(1))))
        }

        #expect(
            try sut.value(of: Warp.Expression.reference([.key("a"), .index(0, optional: true), .indexRef([.key("i")])]))
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

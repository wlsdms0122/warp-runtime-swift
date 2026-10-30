//
//  CaseTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// What a runner refuses as a case, and a case it fails. No case can ask this,
// since a file the runner refuses stops the suite, so it is asked here of a
// case written for it.
@Suite("A case the runner refuses or fails")
struct CaseTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a document laid beside its program does not read")
    func aLaidDocumentThatDoesNotRead() throws {
        // Given. A case expecting the build to refuse, beside a document that
        // writes a key no document has, which no text writes.
        let sut = try Self.writing(
            "documents",
            with: .array([.dictionary(["bogus": .int(1), "imports": .array([]), "warp": .int(1)])]),
            into: try TextEncoding().value(from: """
                (test 1)
                (name "broken")
                (note "a document beside the program that does not read")
                (program (warp 1) (procedure entry (access public) (body (return 1))))
                (expect (refuses build))
                """)
        )

        // When / Then
        #expect {
            try Case(from: sut, in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains("a document laid beside the program does not read")
        }
    }

    @Test("is refused where a procedure it asks for declares a place other than first and second")
    func aBroughtProcedureNamingAnotherPlace() async throws {
        // Given. A procedure the runner brings whose one parameter is not
        // called `first`.
        let sut = try Case(from: try TextEncoding().value(from: """
            (test 1)
            (name "broken")
            (note "a brought procedure naming a place no runner has")
            (vocabulary (procedure App.one (access public) (parameter it (type Int)) (returns Int) (answers 1)))
            (program (warp 1) (import App.one) (procedure entry (access public) (body (return (call App.one 1)))))
            (expect (answers 1))
            """), in: "broken")

        guard case let .program(program) = sut.asked else {
            Issue.record("a case with a program asks about a program")

            return
        }

        // When / Then
        await #expect {
            try await program.brought
        } throws: { error in
            error is ConformanceError && "\(error)".contains("the places a case may name are `first` and `second`")
        }
    }

    @Test("is refused where its vocabulary writes what a vocabulary does not declare", arguments: [
        "(warp 1)", "(const k 1)", "(var v 2)"
    ])
    func aVocabularyKeyItDoesNotDeclare(key: String) throws {
        // When / Then. The runner builds the host's module from what a
        // vocabulary declares, so a key it would not read is refused rather
        // than dropped
        #expect {
            try Case(from: try TextEncoding().value(from: """
                (test 1)
                (name "broken")
                (note "a vocabulary writing a key it does not declare")
                (vocabulary \(key))
                (program (warp 1) (procedure entry (access public) (body (return 1))))
                (expect (answers 1))
                """), in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains("A vocabulary writes `imports` and declares `types`")
        }
    }

    @Test("is refused where it writes a key its subject cannot use", arguments: [
        ("(object (dictionary))", "documents", Value.array([.dictionary([:])]), "a case about an object writes `documents`"),
        ("(bytes x\"57415250010700\")", "documents", Value.array([.dictionary([:])]), "a case about an encoding writes `documents`"),
        ("(text \"(warp 1)\")", "document", Value.bytes([0]), "a case about an encoding writes `document`"),
        ("(program (warp 1))", "document", Value.bytes([0]), "a case about a program writes `document`"),
        ("(program (warp 1))", "argument", Value.dictionary([:]), "a case about a program writes `argument`")
    ])
    func aKeyItsSubjectCannotUse(subject: String, key: Name, held: Value, refusal: String) throws {
        // Given. A case whose subject is read and nothing more, beside a key
        // only another subject is asked with.
        let sut = try Self.writing(key, with: held, into: try TextEncoding().value(from: """
            (test 1)
            (name "broken")
            (note "a key its subject cannot use")
            \(subject)
            (expect (refuses load))
            """))

        // When / Then
        #expect {
            try Case(from: sut, in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains(refusal)
        }
    }

    @Test("is failed where a failure escapes the entry, and a refusal still matches", arguments: [
        ("Standard.Control.abort", "\"on purpose\"", Case.Stage?.none),
        ("Standard.Numeric.dividedBy", "1 0", Case.Stage.run)
    ])
    func aFailureThatEscapes(procedure: String, arguments: String, reached: Case.Stage?) async throws {
        // Given. A case expecting the run to refuse, whose entry either raises
        // a failure nothing catches or is refused by the run.
        let sut = try Case(from: try TextEncoding().value(from: """
            (test 1)
            (name "escaping")
            (note "a failure escaping the entry")
            (program
              (warp 1)
              (import \(procedure))
              (procedure entry
                (access public)
                (returns Double)
                (failing (anything))
                (body
                  (return (call \(procedure) \(arguments))))))
            (expect (refuses run))
            """), in: "escaping")

        guard case let .program(program) = sut.asked else {
            Issue.record("a case with a program asks about a program")

            return
        }

        // When / Then. A failure matches no stage, and a refusal is the run's.
        guard let reached else {
            await #expect {
                try await Runner().reached(program)
            } throws: { error in
                error is ConformanceError && "\(error)".contains("a failure escaped the entry: aborted: on purpose")
            }

            return
        }

        #expect(try await Runner().reached(program)?.stage == reached)
    }

    // MARK: - Public
    // MARK: - Private
    private static func writing(_ key: Name, with held: Value, into tree: Value) throws -> Value {
        guard case let .dictionary(fields) = tree else {
            throw ConformanceError("a case is a mapping")
        }

        return .dictionary(fields.writing(key, with: held))
    }
}

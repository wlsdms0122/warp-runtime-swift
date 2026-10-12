//
//  ModuleNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// The envelope a document is written in. Other suites here write one procedure
// and let `loadProcedure` name it; this one writes the envelope out.
@Suite("The envelope a document is written in")
struct ModuleNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document declares procedures and nothing that runs")
    func documentDeclaresProcedures() throws {
        // Given / When
        let sut = try loader.loadDocument([
            "description": "a document is a module",
            "procedures": [
                "verify": [
                    "parameters": [["name": "path", "type": "String"]],
                    "body": [["let": "done", "value": ["ref": "path"]]]
                ],
                "report": ["body": [["let": "done", "value": "reported"]]]
            ]
        ])

        // Then
        #expect(Set(sut.procedures.keys) == ["verify", "report"])
    }

    @Test("a top-level body is rejected, because a document is not a procedure")
    func topLevelBodyRejected() {
        // Given. A document declares procedures; a body written at its top
        // would be an entry no key names
        let fixture: Value = ["body": [["let": "done", "value": "end"]]]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadDocument(fixture)
        }
    }

    @Test("a module may declare no procedure")
    func aModuleDeclaringNoProcedureIsRead() throws {
        // Given. A module declaring only a type, which the documents beside it
        // name
        let fixture: Value = ["types": ["Geo.Point": ["record": ["x": "Int"]]]]

        // When
        let sut = try loader.loadDocument(fixture)

        // Then
        #expect(sut.procedures.isEmpty)
        #expect(sut.types["Geo.Point"] == .record(["x": .int]))
    }

    @Test("a document carries no name of its own")
    func aDocumentIsNotNamed() {
        // Given. A declaration is named by its key, and a document is what
        // it declares. A key naming the document is a key nothing reads.
        let fixture: Value = [
            "name": "deploy",
            "procedures": ["verify": ["body": [["let": "done", "value": "end"]]]]
        ]

        // When / Then
        #expect {
            try loader.loadDocument(fixture)
        } throws: { error in
            "\(error)".contains("unknown key(s) name")
        }
    }

    @Test("a procedure carries no name of its own")
    func procedureIsNamedByItsKey() {
        // Given. The key is the name, so writing it twice invites the two to
        // disagree
        let fixture: Value = [
            "procedures": [
                "verify": ["name": "something-else", "body": [["let": "done", "value": "end"]]]
            ]
        ]

        // When / Then
        #expect(throws: ReadingError.self) {
            try loader.loadDocument(fixture)
        }
    }

    @Test("a procedure may describe itself")
    func procedureKeepsItsDescription() throws {
        // Given / When
        let sut = try loader.loadDocument([
            "procedures": [
                "verify": [
                    "description": "checks the thing",
                    "body": [["let": "done", "value": "end"]]
                ]
            ]
        ])

        // Then
        #expect(sut.procedures["verify"]?.description == "checks the thing")
    }

    @Test("every procedure in a module is validated, not only the one that runs")
    func everyProcedureIsValidated() {
        // Given. A document is checked against itself, and which one will be
        // the entry is not known here
        let fixture: Value = [
            "procedures": [
                "fine": ["body": [["let": "done", "value": "end"]]],
                "broken": ["body": [["let": "done", "value": ["ref": "nowhere"]]]]
            ]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadDocument(fixture)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

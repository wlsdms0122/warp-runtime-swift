//
//  InterfaceTextTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

// An interface's text: a document's nodes with `(interface 1)` in the place
// of `(warp 1)`, holding what another document may name and each procedure
// as its signature.
@Suite("The text of an interface")
struct InterfaceTextTests {
    // MARK: - Property
    private let sut = TextEncoding()

    // MARK: - Initializer
    // MARK: - Test
    @Test("an interface reads into the module it declares")
    func anInterfaceReads() throws {
        // Given
        let text = """
        (interface 1)
        (import Standard.Comparable)
        (struct App.Range (field low Int) (field high Int))
        (contract App.Named (procedure name (parameter of (type Self)) (returns String)))
        (extension (head Int) (satisfies App.Named) (procedure name (parameter of (type Int)) (returns String)))
        (procedure App.largest (parameter of (type (array (some T Standard.Comparable)))) (returns (optional (some T))))
        """

        // When
        let module = try Loader().interface(try sut.value(from: text))

        // Then
        #expect(Set(module.types.keys) == ["App.Range"])
        #expect(Set(module.contracts.keys) == ["App.Named"])
        #expect(module.claims == ["Int": ["App.Named"]])
        #expect(Set(module.procedures.keys) == ["App.largest", "Int.name"])
        #expect(module.procedures.values.allSatisfy { procedure in procedure.body.statements.isEmpty })
    }

    @Test(
        "an interface refuses what implements a module",
        arguments: [
            ("(interface 1)\n(const seven 7)\n", "holds no `(const …)`"),
            ("(interface 1)\n(var count 0)\n", "holds no `(var …)`"),
            ("(interface 1)\n(procedure App.f (returns Int) (body (return 1)))\n", "holds no `body`"),
            (
                "(interface 1)\n(extension (head Int) (procedure name (access public) (parameter of (type Int)) (returns String)))\n",
                "holds no `access`"
            )
        ]
    )
    func anInterfaceRefusesAnImplementation(text: String, refusal: String) {
        // When / Then
        #expect {
            try sut.value(from: text)
        } throws: { error in
            "\(error)".contains(refusal)
        }
    }

    @Test("an interface is written back as the text it was read from")
    func anInterfaceSpellsAsText() throws {
        // Given
        let text = """
        (interface 1)
        (import Standard.Comparable)

        (struct App.Range
          (field high Int)
          (field low Int))

        (procedure App.largest
          (parameter of (type (array (some T Standard.Comparable))))
          (returns (optional (some T))))

        """

        // When
        let written = try sut.text(from: try sut.value(from: text))

        // Then
        #expect(written == text)
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  DeclaredNameNotationTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/6/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax
import WarpTestSupport

@Suite("A statement says what its name holds under 'type'")
struct DeclaredNameNotationTests {
    // MARK: - Property
    private let loader = Loader()
    private let writer = Writer()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a name reads back holding what the document said it holds")
    func aDeclarationIsRead() throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [["let": "held", "type": "Double", "value": 1], ["value": ["return": ["ref": "held"]]]]
        ])

        // When
        let binding = sut.procedures[entryName]?.body.statements.first?.binding

        // Then
        #expect(binding == .constant("held", declared: .double))
    }

    @Test("a variable that says what it holds reads back with it, bare or not")
    func aBareVariableKeepsItsDeclaration() throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [["var": "held", "type": "Int?"], ["value": ["return": ["ref": "held"]]]]
        ])

        // When
        let binding = sut.procedures[entryName]?.body.statements.first?.binding

        // Then
        #expect(binding == .variable("held", declared: .nullable(.int)))
    }

    @Test("a document the writer wrote reads back holding the same declaration")
    func aDeclarationRoundTrips() throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [["var": "held", "type": "() -> Int", "value": ["closure": ["body": [["value": ["return": 1]]]]]], ["value": ["return": ["ref": "held"]]]]
        ])

        // When
        let again = try loader.load(try writer.value(of: sut), identity: nil)

        // Then
        #expect(
            again.procedures[entryName]?.body.statements.first?.binding
                == sut.procedures[entryName]?.body.statements.first?.binding
        )
    }

    @Test("a write says nothing about what a name holds, so it takes no type")
    func aWriteTakesNoType() throws {
        // When / Then
        #expect {
            try loader.loadProcedure([
                "body": [
                    ["var": "held", "value": 1],
                    ["set": "held", "type": "Int", "value": 2],
                    ["value": ["return": ["ref": "held"]]]
                ]
            ])
        } throws: { error in
            "\(error)".contains("writes 'type', which says what a name holds")
        }
    }

    @Test("a statement run for its effect introduces no name to declare")
    func anUnnamedStatementTakesNoType() throws {
        // When / Then
        #expect {
            try loader.loadProcedure([
                "body": [["type": "Int", "value": 1], ["value": ["return": 1]]]
            ])
        } throws: { error in
            "\(error)".contains("writes 'type', which says what a name holds")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

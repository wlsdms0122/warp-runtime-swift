//
//  WriterRoundTripTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax
import WarpTestSupport

// What the writer writes, the reader reads.
//
// The one promise a canonical writer makes that nothing else checks: a document
// it produced is a document. A key the writer leaves out because it happened to
// be empty is a key the far side may be waiting for, and the cost lands on the
// arrival rather than here, which is the wrong end for it to land on.
@Suite("A document the writer wrote reads back")
struct WriterRoundTripTests {
    // MARK: - Property
    private let sut = Writer()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a construct whose body is empty still writes the key its reader wants")
    func anEmptyBodyIsStillWritten() throws {
        // Given. The three constructs whose `body` the document format calls
        // required.
        let constructs: [Name: Warp.Expression] = [
            "spin": .loop(
                while: .literal(.bool(false)),
                body: []
            ),
            "guarded": .try([], catch: [Statement(expression: .literal(.int(0)))])
        ]

        for (name, expression) in constructs {
            let module = try Module(
                procedures: [entryName: Procedure(access: .public, body: [Statement(binding: .constant(name), expression: expression)])]
            )

            // When
            let written = try sut.value(of: module)

            // Then
            #expect(throws: Never.self) { try Loader().load(written) }
        }
    }

    @Test("a claim that a type conforms to a contract reads back as it was written")
    func aSatisfactionSurvivesAWriting() throws {
        // Given
        let module = try Module(
            types: ["Bank.Account": .struct(["balance": .int])],
            contracts: ["App.Describable": ["describe": Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string)]],
            claims: ["Bank.Account": ["App.Describable"]],
            members: ["Bank.Account": ["describe"]],
            procedures: [
                entryName: Procedure(access: .public, body: []),
                "Bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("Bank.Account"))],
                        returns: .string
                    ),
                    body: [returning(.literal(.string("an account")))]
                )
            ]
        )

        // When
        let written = try sut.value(of: module)

        // Then
        #expect(try Loader().load(written).claims == module.claims)
    }

    // MARK: - Public
    // MARK: - Private
}

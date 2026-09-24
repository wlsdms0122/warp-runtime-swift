//
//  WriterRoundTripTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver
//

import Foundation
import Testing
import Warp
@testable import WarpSyntax

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

    // MARK: - Test
    @Test("a construct whose body is empty still writes the key its reader wants")
    func anEmptyBodyIsStillWritten() async throws {
        // Given. The three constructs whose `body` the document format calls
        // required. A block written as a `block` is the exception and stays
        // one: nothing there has to have it.
        let constructs: [Name: Warp.Expression] = [
            "spin": .loop(
                while: .literal(.bool(false)),
                body: Block(body: []),
                round: "spin"
            ),
            "guarded": .attempt(
                Block(body: []),
                rescue: Block(body: [], result: .literal(.int(0))),
                failure: "guarded"
            )
        ]

        for (name, expression) in constructs {
            let module = try Module(
                procedures: [entryName: Procedure(access: .public, body: [Statement(binding: .constant(name), expression: expression)])]
            )

            // When
            let written = try sut.value(of: module)

            // Then
            await #expect(throws: Never.self) { try Loader().load(written, identity: nil) }
        }
    }

    @Test("a claim that a type answers a contract reads back as it was written")
    func aSatisfactionSurvivesAWriting() throws {
        // Given
        let module = try Module(
            types: ["bank.Account": .record(["balance": .int])],
            contracts: ["app.Describable": ["describe": Signature(returns: .string)]],
            claims: ["bank.Account": ["app.Describable"]],
            procedures: [
                entryName: Procedure(access: .public, body: [], result: .literal(.null)),
                "bank.Account.describe": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .named("bank.Account"))],
                        returns: .string
                    ),
                    body: [],
                    result: .literal(.string("an account"))
                )
            ]
        )

        // When
        let written = try sut.value(of: module)

        // Then
        #expect(try Loader().load(written, identity: nil).claims == module.claims)
    }

    // MARK: - Public
    // MARK: - Private
}

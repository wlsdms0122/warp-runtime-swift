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
// arrival rather than here — which is the wrong end for it to land on.
@Suite("A document the writer wrote reads back")
struct WriterRoundTripTests {
    // MARK: - Property
    private let sut = Writer()

    // MARK: - Test
    @Test("a construct whose body is empty still writes the key its reader wants")
    func anEmptyBodyIsStillWritten() throws {
        // Given — the three constructs whose `body` the document format calls
        // required. A block written as a `group` is the exception and stays
        // one: nothing there has to have it.
        let constructs: [Name: Warp.Expression] = [
            "spin": .loop(
                while: .literal(.bool(false)),
                body: Block(body: []),
                round: "spin"
            ),
            "walk": .iteration(over: .array([]), body: [], element: "walk"),
            "guarded": .attempt(
                Block(body: []),
                rescue: Block(body: [], result: .literal(.int(0))),
                failure: "guarded"
            )
        ]

        for (name, expression) in constructs {
            let module = try Module(
                procedures: [entryName: Procedure(body: [Statement(binding: .constant(name), expression: expression)])]
            )

            // When
            let written = try sut.value(of: module)

            // Then
            #expect(throws: Never.self) { try Loader().load(written, identity: nil) }
        }
    }

    // MARK: - Public
    // MARK: - Private
}

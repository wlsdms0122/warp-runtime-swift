//
//  BinaryDepthTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// The depth of a document is not the depth of the host's call stack, on either
// side of the wire. A reader is handed bytes a sender wrote and a writer is
// handed a value a caller built, and neither of those is owed the process.
//
// What is compared here is bytes rather than values: a document written twice
// answers the same bytes, which is the promise, and it is answerable without
// walking two values side by side.
@Suite("A document nested as deep as the format allows")
struct BinaryDepthTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is written, read and written again at the bound", arguments: [1, 64, 128])
    func survivesAtTheBound(_ deep: Int) throws {
        // Given. Arrays inside arrays, one element each, the innermost holding
        // a value.
        let sut = Self.nested(deep)

        // When. Written, read back, and written a second time.
        let written = try BinaryEncoding().data(from: sut)
        let again = try BinaryEncoding().data(from: try BinaryEncoding().value(from: written))

        // Then. The same bytes, which is the promise a canonical writer makes.
        #expect(again == written)
    }

    @Test("is refused past the bound rather than ending the process")
    func refusesPastTheBound() throws {
        #expect(throws: (any Error).self) {
            try BinaryEncoding().data(from: Self.nested(129))
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func nested(_ deep: Int) -> Value {
        (0 ..< deep).reduce(Value.int(1)) { held, _ in .array([held]) }
    }
}

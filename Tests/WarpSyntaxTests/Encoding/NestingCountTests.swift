//
//  NestingCountTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpSyntax

// One bound, counted one way at every door: containers open on a path. An
// empty container is a container, so a value ending in one is where a count
// that waits for the next value and a count that opens the container part.
@Suite("Nesting is counted alike at every door")
struct NestingCountTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the value model counts the empty container at the bottom")
    func theValueModelCountsTheEmptyContainer() {
        // When / Then
        #expect(Self.nested(Value.nestingBound).nesting == Value.nestingBound)
        #expect(Self.nested(Value.nestingBound + 1).deepest.count == Value.nestingBound)
    }

    @Test("the binary writer admits the bound and refuses one past it")
    func theBinaryWriterHoldsTheBound() throws {
        // When / Then
        _ = try BinaryEncoding().data(from: Self.nested(Value.nestingBound))
        #expect {
            try BinaryEncoding().data(from: Self.nested(Value.nestingBound + 1))
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
    }

    @Test("the binary reader admits the bound and refuses one past it")
    func theBinaryReaderHoldsTheBound() throws {
        // When / Then
        #expect(try BinaryEncoding().value(from: Self.bytes(Value.nestingBound)) == Self.nested(Value.nestingBound))
        #expect {
            try BinaryEncoding().value(from: Self.bytes(Value.nestingBound + 1))
        } throws: { error in
            "\(error)".contains("nests deeper than a reader must follow")
        }
    }

    @Test("the text writer admits the bound and refuses one past it")
    func theTextWriterHoldsTheBound() throws {
        // When / Then
        _ = try TextEncoding().text(from: Self.nested(Value.nestingBound))
        #expect {
            try TextEncoding().text(from: Self.nested(Value.nestingBound + 1))
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
    }

    @Test("the text reader admits the bound and refuses one past it")
    func theTextReaderHoldsTheBound() throws {
        // When / Then
        #expect(try TextEncoding().value(from: Self.text(Value.nestingBound)) == Self.nested(Value.nestingBound))
        #expect {
            try TextEncoding().value(from: Self.text(Value.nestingBound + 1))
        } throws: { error in
            "\(error)".contains("nests deeper than a reader must follow")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // `deep` containers on one path, the innermost holding nothing.
    private static func nested(_ deep: Int) -> Value {
        (1 ..< deep).reduce(Value.array([])) { held, _ in .array([held]) }
    }

    private static func bytes(_ deep: Int) -> Data {
        Data(BinaryEncoding.magic + [BinaryEncoding.format] + Array(repeating: [0x06, 0x01], count: deep - 1).joined() + [0x06, 0x00])
    }

    private static func text(_ deep: Int) -> String {
        "\(TextEncoding.name) \(TextEncoding.format)\n" + String(repeating: "[", count: deep) + String(repeating: "]", count: deep)
    }
}

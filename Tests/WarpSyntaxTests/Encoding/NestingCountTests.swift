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
        _ = try TextEncoding().text(from: Self.document(Value.nestingBound))
        #expect {
            try TextEncoding().text(from: Self.document(Value.nestingBound + 1))
        } throws: { error in
            "\(error)".contains("nests deeper than a document may")
        }
    }

    @Test("the text reader admits the bound and refuses one past it")
    func theTextReaderHoldsTheBound() throws {
        // When / Then
        #expect(try TextEncoding().value(from: Self.text(Value.nestingBound)) == Self.document(Value.nestingBound))
        #expect {
            try TextEncoding().value(from: Self.text(Value.nestingBound + 1))
        } throws: { error in
            "\(error)".contains("nests deeper than a reader must follow")
        }
    }

    @Test("a text walks each shape a tree nests by to the bound, both ways", arguments: [
        ("(warp 1) (const x ", 126, "(array ", "1", ")", ")", 128),
        ("(warp 1) (procedure f (body (return ", 40, "(call f ", "1", ")", ")))", 126),
        ("(warp 1) (procedure f (body (return ", 24, "(closure (body (return ", "1", ")))", ")))", 126),
        ("(warp 1) (procedure f (body ", 30, "(conditional (when true) (then ", "1", "))", "))", 125),
        ("(test 1) (expect (answers ", 126, "(dictionary (entry 1 ", "1", "))", "))", 128),
        ("(warp 1) (type T ", 127, "(array ", "Int", ")", ")", 2),
        ("(warp 1) (type T ", 127, "(procedure (parameters) (returns ", "Int", "))", ")", 2)
    ])
    func eachShapeWalksTheBound(
        head: String,
        deep: Int,
        open: String,
        inner: String,
        close: String,
        tail: String,
        nesting: Int
    ) throws {
        // Given. Text the second layer reads by recursion, a node a level, on
        // a test's task stack in a debug build. A type nests in its own nodes
        // as deep as a tree may, inside one text of the tree
        let text = head + String(repeating: open, count: deep) + inner + String(repeating: close, count: deep) + tail

        // When
        let sut = try TextEncoding().value(from: text)

        // Then
        #expect(sut.nesting == nesting)
        #expect(try TextEncoding().value(from: try TextEncoding().text(from: sut)) == sut)
    }

    @Test("a map's key opens what it holds like any value, at every door")
    func aKeyIsCountedLikeAValue() throws {
        // Given. A map whose one key is a path of containers, so the map and
        // the key's containers stand on one path. A case's text carries it two
        // containers in, under what the case expects
        let within = Value.dictionary(try Value.Dictionary([(key: Self.nested(Value.nestingBound - 1), value: .null)]))
        let past = Value.dictionary(try Value.Dictionary([(key: Self.nested(Value.nestingBound), value: .null)]))
        let expecting = { (answer: Value) in
            Value.dictionary(["test": .int(1), "expect": .dictionary(["answers": answer])])
        }
        let inCase = Value.dictionary(try Value.Dictionary([(key: Self.nested(Value.nestingBound - 3), value: .null)]))

        // When / Then
        #expect(within.nesting == Value.nestingBound)
        #expect(past.nesting == Value.nestingBound + 1)
        #expect(try BinaryEncoding().value(from: try BinaryEncoding().data(from: within)) == within)
        #expect(try TextEncoding().value(from: try TextEncoding().text(from: expecting(inCase))) == expecting(inCase))
        #expect(throws: EncodingRefused.self) { try BinaryEncoding().data(from: past) }
        #expect(throws: EncodingRefused.self) { try TextEncoding().text(from: expecting(within)) }
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

    // A document `deep` containers down: the document, its constants and
    // arrays down to the last.
    private static func document(_ deep: Int) -> Value {
        .dictionary(["warp": .int(1), "imports": .array([]), "const": .dictionary(["x": nested(deep - 2)])])
    }

    private static func text(_ deep: Int) -> String {
        "(warp 1) (const x " + String(repeating: "(array ", count: deep - 2) + String(repeating: ")", count: deep - 2) + ")"
    }
}

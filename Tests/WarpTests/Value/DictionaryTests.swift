//
//  DictionaryTests.swift
//  WarpTests
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A dictionary holds entries under keys that are values")
struct DictionaryTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("entries stand in the key order whichever way they were given")
    func entriesAreInKeyOrder() throws {
        // Given
        let byFields = Value.Dictionary(["b": .int(2), "a": .int(1), "c": .int(3)])
        let byEntries = try Value.Dictionary(
            [(key: Value.string("c"), value: Value.int(3)), (key: "a", value: .int(1)), (key: "b", value: .int(2))]
        )

        // When / Then
        #expect(byFields.keys == ["a", "b", "c"])
        #expect(byFields == byEntries)
        #expect(byFields.values == [.int(1), .int(2), .int(3)])
    }

    @Test("keys order by kind, then within the kind")
    func keysOrderByKindThenWorth() throws {
        // Given
        let sut = try Value.Dictionary([
            (key: Value.string("a"), value: .int(0)),
            (key: .array([.int(1)]), value: .int(0)),
            (key: .double(1.5), value: .int(0)),
            (key: .bool(true), value: .int(0)),
            (key: .int(1), value: .int(0)),
            (key: .null, value: .int(0)),
            (key: .bool(false), value: .int(0)),
            (key: .array([]), value: .int(0)),
            (key: .int(-3), value: .int(0))
        ])

        // When / Then
        #expect(sut.keys == [.null, .bool(false), .bool(true), .int(-3), .int(1), .double(1.5), "a", .array([]), .array([.int(1)])])
    }

    @Test("a key written twice is refused, by sameness", arguments: [
        (Value.string("a"), Value.string("a")),
        (Value.int(1), Value.double(1)),
        (Value.bytes([104, 105]), Value.array([.int(104), .int(105)]))
    ])
    func aRepeatedKeyIsRefused(one: Value, other: Value) {
        // When / Then
        #expect(throws: ValueRefused.self) {
            try Value.Dictionary([(key: one, value: Value.int(1)), (key: other, value: .int(3))])
        }
    }

    @Test("an entry is found by its key, the same value under another spelling included")
    func anEntryIsFoundByKey() throws {
        // Given
        let names = try (0 ..< 40).map { index in try Name("field\(index)") }
        let sut = try Value.Dictionary(names.reversed().map { name in (key: Value.string(name.spelling), value: Value.string(name.spelling)) })
        let numbered = try Value.Dictionary([(key: Value.int(1), value: Value.string("one"))])

        // When / Then
        for name in names {
            #expect(sut[name] == .string(name.spelling))
        }
        #expect(sut["field40"] == nil)
        #expect(Value.Dictionary([:])["a"] == nil)
        #expect(numbered[key: .double(1)] == .string("one"))
        #expect(numbered[key: .int(2)] == nil)
    }

    @Test("a Double that is not a number is a key never found again")
    func notANumberIsNeverFound() {
        // Given
        let sut = Value.Dictionary([:]).writing(key: .double(.nan), with: .int(1))

        // When / Then
        #expect(sut.count == 1)
        #expect(sut[key: .double(.nan)] == nil)
        #expect(sut.writing(key: .double(.nan), with: .int(2)).count == 2)
    }

    @Test("writing an entry replaces a held one in place and puts a new one where it orders")
    func writingKeepsTheOrder() {
        // Given
        let sut = Value.Dictionary(["a": .int(1), "c": .int(3)])

        // When
        let replaced = sut.writing("c", with: .int(30))
        let inserted = sut.writing("b", with: .int(2))
        let appended = sut.writing("d", with: .int(4))
        let numbered = sut.writing(key: .int(7), with: .int(7))

        // Then
        #expect(replaced.values == [.int(1), .int(30)])
        #expect(inserted.keys == ["a", "b", "c"])
        #expect(appended.keys == ["a", "c", "d"])
        #expect(numbered.keys == [.int(7), "a", "c"])
    }

    @Test("removing takes a held entry out and leaves a dictionary without it as it is")
    func removingAnEntry() {
        // Given
        let sut = Value.Dictionary(["a": .int(1), "b": .int(2)])

        // When / Then
        #expect(sut.removing("a").keys == ["b"])
        #expect(sut.removing("z") == sut)
    }

    // MARK: - Public
    // MARK: - Private
}

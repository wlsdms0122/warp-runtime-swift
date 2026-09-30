//
//  DictionaryTests.swift
//  WarpTests
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A dictionary holds names that are the value's own")
struct DictionaryTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("entries stand in the byte order of their names whichever way they were given")
    func entriesAreOrderedByBytes() throws {
        // Given
        let byFields = Value.Dictionary(["b": .int(2), "a": .int(1), "c": .int(3)])
        let byEntries = try Value.Dictionary(
            [(name: "c", value: Value.int(3)), (name: "a", value: .int(1)), (name: "b", value: .int(2))]
        )

        // When / Then
        #expect(byFields.names == ["a", "b", "c"])
        #expect(byFields == byEntries)
        #expect(byFields.values == [.int(1), .int(2), .int(3)])
    }

    @Test("a name written twice is refused")
    func aRepeatedNameIsRefused() {
        #expect(throws: ValueRefused.self) {
            try Value.Dictionary([(name: "a", value: Value.int(1)), (name: "a", value: .int(3))])
        }
    }

    @Test("an entry is found by its name, and a name not held answers nil")
    func anEntryIsFoundByName() throws {
        // Given
        let names = try (0 ..< 40).map { index in try Name("field\(index)") }
        let sut = try Value.Dictionary(names.reversed().map { name in (name: name, value: Value.string(name.spelling)) })

        // When / Then
        for name in names {
            #expect(sut[name] == .string(name.spelling))
        }
        #expect(sut["field40"] == nil)
        #expect(Value.Dictionary([:])["a"] == nil)
    }

    @Test("writing an entry replaces a held one in place and puts a new one where it sorts")
    func writingKeepsTheOrder() {
        // Given
        let sut = Value.Dictionary(["a": .int(1), "c": .int(3)])

        // When
        let replaced = sut.writing("c", with: .int(30))
        let inserted = sut.writing("b", with: .int(2))
        let appended = sut.writing("d", with: .int(4))

        // Then
        #expect(replaced.values == [.int(1), .int(30)])
        #expect(inserted.names == ["a", "b", "c"])
        #expect(appended.names == ["a", "c", "d"])
    }

    @Test("removing takes a held entry out and leaves a dictionary without it as it is")
    func removingAnEntry() {
        // Given
        let sut = Value.Dictionary(["a": .int(1), "b": .int(2)])

        // When / Then
        #expect(sut.removing("a").names == ["b"])
        #expect(sut.removing("z") == sut)
    }

    // MARK: - Public
    // MARK: - Private
}

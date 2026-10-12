//
//  MutatorTests.swift
//  WarpMutationTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
@testable import Warp
import WarpMutation

@Suite("A mutator")
struct MutatorTests {
    // MARK: - Property
    private let sut = Mutator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("walks the fields of a named record the way it walks a dictionary's")
    func aNamedRecordIsWalked() {
        // Given
        let point = Value.record(Record(name: "App.Point", ["x": .int(1), "y": .int(2)]))

        // When
        let mutations = sut.mutations(of: point)

        // Then. The record and each of its fields is a place
        #expect(sut.placeCount(of: point) == 3)
        #expect(
            mutations.contains { mutation in
                mutation.path == ".x"
                    && mutation.value == .record(Record(name: "App.Point", ["x": .int(-1), "y": .int(2)]))
            }
        )
    }

    @Test("walks every key of a map and the entry under it, whatever its keys")
    func everyKeyAndEntryOfAMapIsWalked() throws {
        // Given
        let map = Value.dictionary(
            try Value.Dictionary([
                (key: .int(1), value: .int(1)),
                (key: .string("a"), value: .int(2)),
                (key: .array([.bool(true)]), value: .int(3))
            ])
        )

        let replaced = Value.dictionary(
            try Value.Dictionary([
                (key: .int(1), value: .int(-1)),
                (key: .string("a"), value: .int(2)),
                (key: .array([.bool(true)]), value: .int(3))
            ])
        )

        let rekeyed = Value.dictionary(
            try Value.Dictionary([
                (key: .int(-1), value: .int(1)),
                (key: .string("a"), value: .int(2)),
                (key: .array([.bool(true)]), value: .int(3))
            ])
        )

        // When
        let mutations = sut.mutations(of: map)

        // Then. The map, each of its keys, the element the list key holds,
        // and the value under each key is a place
        #expect(sut.placeCount(of: map) == 8)
        #expect(mutations.contains { mutation in mutation.path == "[1]" && mutation.value == replaced })
        #expect(mutations.contains { mutation in mutation.path == "[key 1]" && mutation.value == rekeyed })
    }

    // MARK: - Public
    // MARK: - Private
}

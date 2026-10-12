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
    @Test("walks a record's fields the way it walks a map's entries")
    func aRecordIsWalked() {
        // Given
        let point = Value.record(Record(name: "App.Point", ["x": .int(1), "y": .int(2)]))

        // When
        let mutations = sut.mutations(of: point)

        // Then. The record and each of its fields is a place
        #expect(sut.placeCount(of: point) == 3)
        #expect(
            mutations.contains { mutation in
                mutation.path == "x"
                    && mutation.value == .record(Record(name: "App.Point", ["x": .int(-1), "y": .int(2)]))
            }
        )
    }

    @Test("walks every entry of a map, whatever its keys")
    func everyEntryOfAMapIsWalked() throws {
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

        // When
        let mutations = sut.mutations(of: map)

        // Then. The map and the value under each of its keys is a place
        #expect(sut.placeCount(of: map) == 4)
        #expect(mutations.contains { mutation in mutation.path == "1" && mutation.value == replaced })
    }

    // MARK: - Public
    // MARK: - Private
}

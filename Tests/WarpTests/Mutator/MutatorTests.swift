//
//  MutatorTests.swift
//  WarpTests
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
        let point = Value.record(Record(name: "app.Point", ["x": .int(1), "y": .int(2)]))

        // When
        let mutations = sut.mutations(of: point)

        // Then. The record and each of its fields is a place
        #expect(sut.placeCount(of: point) == 3)
        #expect(
            mutations.contains { mutation in
                mutation.path == "x"
                    && mutation.value == .record(Record(name: "app.Point", ["x": .int(-1), "y": .int(2)]))
            }
        )
    }

    // MARK: - Public
    // MARK: - Private
}

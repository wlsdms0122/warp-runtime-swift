//
//  InPlaceTableTests.swift
//  WarpTests
//
//  Created by JSilver on 10/2/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("The in-place table")
struct InPlaceTableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("calls recorded at different places are each held")
    func recordingKeepsEveryPlace() {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        var sut = InPlaceTable()

        // When
        sut.record([0], at: first)
        sut.record([], at: second)

        // Then
        #expect(sut[first] == [0])
        #expect(sut[second] == [])
    }

    @Test("two tables naming calls at different places hold both")
    func absorbingKeepsEveryPlace() {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        var sut = InPlaceTable()
        var other = InPlaceTable()

        sut.record([0], at: first)
        other.record([], at: second)

        // When
        sut.absorb(other)

        // Then
        #expect(sut[first] == [0])
        #expect(sut[second] == [])
    }

    // MARK: - Public
    // MARK: - Private
}

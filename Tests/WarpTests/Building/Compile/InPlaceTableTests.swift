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
    func recordingKeepsEveryPlace() throws {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        var sut = InPlaceTable()

        // When
        try sut.record([0], at: first)
        try sut.record([], at: second)

        // Then
        #expect(sut[first] == [0])
        #expect(sut[second] == [])
    }

    @Test("a second call recorded at one place is refused rather than one kept")
    func recordingOnePlaceTwiceRefuses() throws {
        // Given
        let place = Place.procedure("entry", in: .assembled).child(.argument(0))
        var sut = InPlaceTable()

        try sut.record([0], at: place)

        // When / Then
        #expect(throws: BuildError.self) {
            try sut.record([], at: place)
        }
        #expect(sut[place] == [0])
    }

    @Test("two tables naming calls at different places hold both")
    func absorbingKeepsEveryPlace() throws {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        var sut = InPlaceTable()
        var other = InPlaceTable()

        try sut.record([0], at: first)
        try other.record([], at: second)

        // When
        try sut.absorb(other)

        // Then
        #expect(sut[first] == [0])
        #expect(sut[second] == [])
    }

    @Test("absorbing a call at a place already held is refused")
    func absorbingOnePlaceTwiceRefuses() throws {
        // Given
        let place = Place.procedure("entry", in: .assembled).child(.argument(0))
        var sut = InPlaceTable()
        var other = InPlaceTable()

        try sut.record([0], at: place)
        try other.record([], at: place)

        // When / Then
        #expect(throws: BuildError.self) {
            try sut.absorb(other)
        }
    }

    // MARK: - Public
    // MARK: - Private
}

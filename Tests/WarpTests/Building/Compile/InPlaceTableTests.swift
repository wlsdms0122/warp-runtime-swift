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
    @Test("two tables naming calls at different places hold both")
    func absorbingKeepsEveryPlace() throws {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        let sut = InPlaceTable([first: [0]])

        // When
        let absorbed = try sut.absorbing(InPlaceTable([second: []]))

        // Then
        #expect(absorbed[first] == [0])
        #expect(absorbed[second] == [])
    }

    @Test("two calls at one place are refused rather than one kept")
    func absorbingOnePlaceTwiceRefuses() {
        // Given
        let place = Place.procedure("entry", in: .assembled).child(.argument(0))
        let sut = InPlaceTable([place: [0]])

        // When / Then
        #expect(throws: BuildError.self) {
            try sut.absorbing(InPlaceTable([place: []]))
        }
    }

    // MARK: - Public
    // MARK: - Private
}

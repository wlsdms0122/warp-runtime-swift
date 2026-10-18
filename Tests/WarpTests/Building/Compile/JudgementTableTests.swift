//
//  JudgementTableTests.swift
//  WarpTests
//
//  Created by JSilver on 10/2/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("The judgement table")
struct JudgementTableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("judgements recorded at different places are each held")
    func recordingKeepsEveryPlace() {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        var sut = JudgementTable()

        // When
        sut.record(.apply(inPlace: [0], declared: nil), at: first)
        sut.record(.apply(inPlace: [1], declared: nil), at: second)

        // Then
        #expect(handed(at: first, in: sut) == [0])
        #expect(handed(at: second, in: sut) == [1])
    }

    @Test("two tables naming different places hold both")
    func absorbingKeepsEveryPlace() {
        // Given
        let first = Place.procedure("entry", in: .assembled).child(.argument(0))
        let second = Place.procedure("entry", in: .assembled).child(.argument(1))
        var sut = JudgementTable()
        var other = JudgementTable()

        sut.record(.apply(inPlace: [0], declared: nil), at: first)
        other.record(.apply(inPlace: [], declared: nil), at: second)

        // When
        sut.absorb(other)

        // Then
        #expect(handed(at: first, in: sut) == [0])
        #expect(handed(at: second, in: sut) == [])
    }

    // MARK: - Public
    // MARK: - Private
    private func handed(at place: Place, in table: JudgementTable) -> [Int]? {
        guard case let .apply(handed, _)? = table[place] else { return nil }

        return handed
    }
}

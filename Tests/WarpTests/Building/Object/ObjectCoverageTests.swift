//
//  ObjectCoverageTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp

// An object naming every kind of thing an object can name.
//
// The specification's cases round-trip whole programs, and those reach only
// the kinds programs happen to be written out of.
//
// A kind the pair disagrees about is a silent one. The writing and the reading
// would each be exhaustive, each be compiled, and the object would come back
// as something else. So this stands one of everything up and asks the pair to
// agree, and it holds a distinct value in every field so that two fields
// swapped between the two sides is a difference and not a coincidence.
@Suite("An object of one of everything")
struct ObjectCoverageTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("reads back as the object it was written from")
    func everyKindSurvives() throws {
        // Given / When. Written, read, and written again.
        let sut = ObjectCoverageFixture.everything

        let written = try sut.object()
        let read = try Compiled(written: written, of: sut.identity)

        // Then. One object is one writing, and a pair that disagreed about
        // any one kind would part here.
        #expect(try read.object() == written)
    }

    @Test("is written under exactly the keys the layout names")
    func everyKeyIsTheLayouts() throws {
        // Given / When. The writer and the reading both key the map by the
        // layout's keys.
        guard case let .dictionary(written) = try ObjectCoverageFixture.everything.object() else {
            Issue.record("an object is written as a map")

            return
        }

        // Then
        #expect(Set(try written.named().map(\.name)) == ObjectLayout.keys)
    }

    // MARK: - Public
    // MARK: - Private
}

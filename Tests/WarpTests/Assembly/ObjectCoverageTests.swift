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
// The specification's cases round-trip whole programs, and what they reach is
// what programs happen to be written out of: measured, 55 of the 122 kinds a
// writing can lay down are never among them. `Construct`, `Argument` and
// `LoweredType.Bound` are reached by none of them at all.
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

        guard let written = sut.written else {
            Issue.record("an object of one of everything is one an object can hold")

            return
        }

        let read = try Compiled(written: written, of: sut.identity)

        // Then. One object is one writing, and a pair that disagreed about
        // any one kind would part here.
        #expect(read.written == written)
    }

    @Test("is written under exactly the keys the layout names")
    func everyKeyIsTheLayouts() throws {
        // Given. The writer lays its keys down as a literal, and the reading
        // holds a record to the layout's list. The two are one layout only
        // while they agree.
        guard case let .dictionary(written)? = ObjectCoverageFixture.everything.written else {
            Issue.record("an object is written as a record")

            return
        }

        // Then
        #expect(Set(written.names) == Compiled.parts)
    }

    // MARK: - Public
    // MARK: - Private
}

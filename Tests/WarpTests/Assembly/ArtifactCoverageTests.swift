//
//  ArtifactCoverageTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp

// An artifact naming every kind of thing an artifact can name.
//
// The specification's cases round-trip whole programs, and what they reach is
// what programs happen to be written out of: measured, 55 of the 122 kinds a
// writing can lay down are never among them. `Construct`, `Argument` and
// `LoweredType.Bound` are reached by none of them at all.
//
// A kind the pair disagrees about is a silent one. The writing and the reading
// would each be exhaustive, each be compiled, and the artifact would come back
// as something else. So this stands one of everything up and asks the pair to
// agree, and it holds a distinct value in every field so that two fields
// swapped between the two sides is a difference and not a coincidence.
@Suite("An artifact of one of everything")
struct ArtifactCoverageTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("reads back as the artifact it was written from")
    func everyKindSurvives() throws {
        // Given / When. Written, read, and written again.
        let sut = ArtifactCoverageFixture.everything

        guard let written = sut.written else {
            Issue.record("an artifact of one of everything is one an artifact can hold")

            return
        }

        let read = try Compiled(written: written, of: sut.identity)

        // Then. One artifact is one writing, and a pair that disagreed about
        // any one kind would part here.
        #expect(read.written == written)
    }

    // MARK: - Public
    // MARK: - Private
}

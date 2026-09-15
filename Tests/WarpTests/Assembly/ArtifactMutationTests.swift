//
//  ArtifactMutationTests.swift
//  WarpTests
//
//  Created by JSilver on 9/14/26.
//

import Foundation
import Testing
@testable import Warp
import WarpMutation

// What a reading does with every field of an artifact replaced in turn.
//
// The cases beside this one each name a field and say what is refused there,
// which asks about the fields someone thought of. This asks about all of them.
// A refusal is an answer. A trap is not, because the reading runs inside a
// host's process and a trap there ends the host.
//
// The fixture is the one that names every kind, so a mutation reaches kinds
// that no program is written out of.
@Suite("An artifact with one place of it replaced")
struct ArtifactMutationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused wherever it is mutated, and never traps")
    func everyMutationIsAnswered() throws {
        guard let written = Self.everything.written else {
            Issue.record("an artifact of one of everything is one an artifact can hold")

            return
        }

        let mutator = Mutator()
        var mutations = 0

        for (path, mutated) in mutator.mutations(of: written) {
            mutations += 1

            // A reading that throws has answered. A reading that returns has
            // read something it is willing to stand behind, and that is an
            // answer too: the mutation landed somewhere the writing does not
            // read.
            do {
                let read = try Compiled(written: mutated, of: Self.everything.identity)

                // Whatever it stood up is written again, because a reading that
                // admits a value it cannot write back, or writes back as
                // something else, has taken the artifact somewhere the pair
                // does not agree on.
                guard let once = read.written else {
                    Issue.record("a mutation at \(path) read back as an artifact that cannot be written")

                    continue
                }

                #expect(once == mutated, "a mutation at \(path) is admitted and written back as something else")
            } catch is ArtifactRefused {
            } catch {
                Issue.record("a mutation at \(path) was refused as \(type(of: error)), not as an artifact")
            }
        }

        #expect(mutations > 500, "the walk reached \(mutations) places, which is fewer than this fixture holds")
    }

    // MARK: - Public
    // MARK: - Private
    private static let everything = ArtifactCoverageFixture.everything
}

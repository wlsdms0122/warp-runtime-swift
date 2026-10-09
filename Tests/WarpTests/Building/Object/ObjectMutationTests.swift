//
//  ObjectMutationTests.swift
//  WarpTests
//
//  Created by JSilver on 9/14/26.
//

import Foundation
import Testing
@testable import Warp
import WarpMutation

// What a reading does with every field of an object replaced in turn.
//
// The tests beside this one each name a field and say what is refused there,
// which asks about the fields someone thought of. This asks about all of them.
// A refusal is an answer. A trap is not, because the reading runs inside a
// host's process and a trap there ends the host.
//
// The fixture is the one that names every kind, so a mutation reaches kinds
// that no program is written out of.
@Suite("An object with one place of it replaced")
struct ObjectMutationTests {
    // MARK: - Property
    private static let everything = ObjectCoverageFixture.everything

    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused or read back as it was written wherever it is mutated, and never traps")
    func everyMutationIsAnswered() throws {
        // Given
        let written = try Self.everything.object()

        let mutator = Mutator()
        var mutations = 0

        // When / Then
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
                // something else, has taken the object somewhere the pair
                // does not agree on.
                let once: Value

                do {
                    once = try read.object()
                } catch {
                    Issue.record("a mutation at \(path) read back as an object that cannot be written: \(error)")

                    continue
                }

                #expect(once == mutated, "a mutation at \(path) is admitted and written back as something else")
            } catch is ObjectRefused {
            } catch {
                Issue.record("a mutation at \(path) was refused as \(type(of: error)), not as an object")
            }
        }

        // Every place the fixture holds is walked, and a place yields at least
        // one neighbour, so a walk that reached fewer mutations than the
        // fixture has places is a walk that stopped somewhere.
        let places = mutator.placeCount(of: written)

        #expect(
            mutations >= places,
            "the walk made \(mutations) mutations of a writing standing in \(places) places"
        )
    }

    // MARK: - Public
    // MARK: - Private
}

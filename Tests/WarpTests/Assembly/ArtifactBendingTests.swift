//
//  ArtifactBendingTests.swift
//  WarpTests
//
//  Created by JSilver on 9/14/26.
//

import Foundation
import Testing
@testable import Warp

// What a reading does with every field of an artifact bent in turn.
//
// The cases beside this one each name a field and say what is refused there,
// which asks about the fields someone thought of. This asks about all of them:
// it walks the writing, bends one place at a time, and hands the result back
// to the reading. A refusal is an answer. A trap is not, because the reading
// runs inside a host's process and a trap there ends the host.
//
// The fixture is the one that names every kind, so a bend reaches kinds that
// no program is written out of.
@Suite("An artifact bent one place at a time")
struct ArtifactBendingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused wherever it is bent, and never traps")
    func everyBendIsAnswered() throws {
        guard let written = Self.everything.written else {
            Issue.record("an artifact of one of everything is one an artifact can hold")

            return
        }

        var bends = 0

        for (path, bent) in Self.bendings(of: written) {
            bends += 1

            // A reading that throws has answered. A reading that returns has
            // read something it is willing to stand behind, and that is an
            // answer too: the bend landed somewhere the writing does not read.
            do {
                let read = try Compiled(written: bent, of: Self.everything.identity)

                // Whatever it stood up is written again and read again, because
                // a reading that admits a value it cannot write back, or writes
                // back as something else, has taken the artifact somewhere the
                // pair does not agree on.
                guard let once = read.written else {
                    Issue.record("bend at \(path) read back as an artifact that cannot be written")

                    continue
                }

                let twice = try Compiled(written: once, of: Self.everything.identity).written

                #expect(twice == once, "bend at \(path) is written one way and read back as another")
            } catch is ArtifactRefused {
            } catch {
                Issue.record("bend at \(path) was refused as \(type(of: error)), not as an artifact")
            }
        }

        #expect(bends > 500, "the walk reached \(bends) places, which is fewer than this fixture holds")
    }

    // MARK: - Public
    // MARK: - Private
    private static let everything = ArtifactCoverageFixture.everything

    // Every place in the writing, each bent the ways its kind can be bent.
    //
    // A number is the one that indexes, counts and names rows, so it is bent
    // to the three shapes an index goes wrong in. A list is bent in length,
    // because a reading that takes fields by position reads a shorter list
    // somewhere. The rest are bent to a neighbouring kind, which is what a
    // reading that switches on the kind has to refuse.
    private static func bendings(of value: Value) -> [(path: String, value: Value)] {
        var bendings: [(path: String, value: Value)] = []

        walk(value, at: "") { path, held in
            for bent in bends(of: held) {
                bendings.append((path, replacing(path, in: value, with: bent)))
            }
        }

        return bendings
    }

    private static func bends(of value: Value) -> [Value] {
        switch value {
        case let .int(number):
            return [.int(-1), .int(Int.max), .int(number &+ 1), .string("not a number")]

        case let .array(elements):
            var bends: [Value] = [.array(elements.dropLast()), .array([]), .int(0)]

            if let first = elements.first { bends.append(.array(elements + [first])) }

            return bends

        case let .string(spelling):
            return [.string(""), .string(spelling + "\u{0301}"), .int(0)]

        case let .bool(flag):
            return [.bool(!flag), .int(0)]

        case .null:
            return [.int(0), .array([])]

        default:
            return [.null, .int(0)]
        }
    }

    private static func walk(_ value: Value, at path: String, _ visit: (String, Value) -> Void) {
        visit(path, value)

        guard case let .array(elements) = value else { return }

        for (position, element) in elements.enumerated() {
            walk(element, at: path.isEmpty ? "\(position)" : "\(path).\(position)", visit)
        }
    }

    private static func replacing(_ path: String, in value: Value, with bent: Value) -> Value {
        guard !path.isEmpty else { return bent }

        return replacing(path.split(separator: ".").map { Int($0) ?? 0 }, in: value, with: bent)
    }

    private static func replacing(_ positions: [Int], in value: Value, with bent: Value) -> Value {
        guard let position = positions.first else { return bent }
        guard case var .array(elements) = value, elements.indices.contains(position) else { return value }

        elements[position] = replacing(Array(positions.dropFirst()), in: elements[position], with: bent)

        return .array(elements)
    }
}

//
//  Mutator.swift
//  WarpMutation
//
//  Created by JSilver on 9/15/26.
//

import Foundation
import Warp

// One place of a value replaced, over every place the value holds.
//
// What this is for is asking a reading what it does with a writing that is not
// one. Naming a field and saying what is refused there asks about the fields
// someone thought of; this asks about all of them, and the answer a reading
// owes is the same either way: a refusal, or a value it stands behind.
//
// One place at a time, because a mutant that differs in two places cannot say
// which of them the answer was about.
public struct Mutator: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() { }

    // MARK: - Public
    // Every place in the value, each replaced the ways its kind can be.
    //
    // A number is the one that indexes, counts and names rows, so it is
    // replaced by the three shapes an index goes wrong in. A list is replaced
    // in length, because a reading that takes fields by position reads a
    // shorter list somewhere. The rest take a neighbouring kind, which is what
    // a reading that switches on the kind has to refuse.
    public func mutations(of value: Value) -> [(path: String, value: Value)] {
        var mutations: [(path: String, value: Value)] = []

        // A neighbour that is the value again is not one. An empty list
        // shortened is still empty, and a place left as it was asks the reading
        // what it already answered rather than anything new.
        walk(value, at: []) { steps, held in
            for mutated in self.mutations(ofPlace: held) where mutated != held {
                mutations.append((Self.spelled(steps), replacing(steps[...], in: value, with: mutated)))
            }
        }

        return mutations
    }

    // How many places the value holds, which is what a walk of it reaches. A
    // caller asking how far a walk should have got reads it off the value
    // rather than off a number somebody counted once.
    public func placeCount(of value: Value) -> Int {
        var places = 0

        walk(value, at: []) { _, _ in places += 1 }

        return places
    }

    // MARK: - Private
    // One step down into a value: a position in a list, or a key in a record.
    private enum Step {
        case position(Int)
        case key(Name)
    }

    private static func spelled(_ steps: [Step]) -> String {
        steps.map { step in
            switch step {
            case let .position(position): String(position)
            case let .key(key): key.spelling
            }
        }.joined(separator: "/")
    }

    private func mutations(ofPlace value: Value) -> [Value] {
        switch value {
        case let .int(number):
            return [.int(-1), .int(.max), .int(number &+ 1), .string("not a number")]

        case let .array(elements):
            var mutations: [Value] = [.array(elements.dropLast()), .array([]), .int(0)]

            if let first = elements.first { mutations.append(.array(elements + [first])) }

            return mutations

        case let .dictionary(record):
            var mutations: [Value] = [.dictionary(Value.Dictionary([:])), .array([]), .int(0)]

            if let first = record.names.first { mutations.append(.dictionary(record.removing(first))) }

            mutations.append(.dictionary(record.writing("mutated", with: .null)))

            return mutations

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

    private func walk(_ value: Value, at steps: [Step], _ visit: ([Step], Value) -> Void) {
        visit(steps, value)

        switch value {
        case let .array(elements):
            for (position, element) in elements.enumerated() {
                walk(element, at: steps + [.position(position)], visit)
            }

        case let .dictionary(record):
            for entry in record.entries {
                walk(entry.value, at: steps + [.key(entry.name)], visit)
            }

        default:
            return
        }
    }

    private func replacing(_ steps: ArraySlice<Step>, in value: Value, with mutated: Value) -> Value {
        guard let step = steps.first else { return mutated }

        switch (step, value) {
        case let (.position(position), .array(elements)) where elements.indices.contains(position):
            var replaced = elements

            replaced[position] = replacing(steps.dropFirst(), in: elements[position], with: mutated)

            return .array(replaced)

        case let (.key(key), .dictionary(record)):
            guard let held = record[key] else { return value }

            return .dictionary(record.writing(key, with: replacing(steps.dropFirst(), in: held, with: mutated)))

        default:
            return value
        }
    }
}

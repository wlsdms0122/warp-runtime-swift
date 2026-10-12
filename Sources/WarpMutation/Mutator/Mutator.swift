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
    // One step down into a value: a position in a list, the entry under a
    // key of a map, the key itself, or a field of a record.
    private enum Step {
        case position(Int)
        case entry(Value)
        case key(Value)
        case field(Name)
    }

    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // Every place in the value, each replaced the ways its kind can be.
    //
    // A number is the one that indexes, counts and names rows, so it is
    // replaced by the shapes an index goes wrong in, and by text. A list is replaced
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
                guard let replaced = replacing(steps[...], in: value, with: mutated) else { continue }

                mutations.append((Self.spelled(steps), replaced))
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
    // Written as a path is, a list's position and a map's key between
    // brackets and a field after a dot, and a key itself marked as the key
    // rather than the entry under it.
    private static func spelled(_ steps: [Step]) -> String {
        steps.map { step in
            switch step {
            case let .position(position): Path([.index(.int(position))]).rendered
            case let .entry(key): Path([.index(key)]).rendered
            case let .key(key): "[key \(Rendering(key).text())]"
            case let .field(name): ".\(name.spelling)"
            }
        }.joined()
    }

    private func mutations(ofPlace value: Value) -> [Value] {
        switch value {
        case let .int(number):
            return [.int(-1), .int(.max), .int(number &+ 1), .string("not a number")]

        case let .array(elements):
            var mutations: [Value] = [.array(elements.dropLast()), .array([]), .int(0), .dictionary(Value.Dictionary([:]))]

            if let first = elements.first { mutations.append(.array(elements + [first])) }

            return mutations

        // Bytes are a list in a compact spelling, so they are replaced in
        // length the same way, which is how an identity or a fingerprint
        // reads wrong.
        case let .bytes(bytes):
            var mutations: [Value] = [.bytes(Array(bytes.dropLast())), .bytes([]), .int(0), .dictionary(Value.Dictionary([:]))]

            if let first = bytes.first { mutations.append(.bytes(bytes + [first])) }

            return mutations

        case let .dictionary(dictionary):
            var mutations: [Value] = [.dictionary(Value.Dictionary([:])), .array([]), .int(0)]

            if let first = dictionary.keys.first { mutations.append(.dictionary(dictionary.removing(key: first))) }

            mutations.append(.dictionary(dictionary.writing("mutated", with: .null)))

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

        case let .dictionary(dictionary):
            for entry in dictionary.entries {
                walk(entry.key, at: steps + [.key(entry.key)], visit)
                walk(entry.value, at: steps + [.entry(entry.key)], visit)
            }

        case let .record(record):
            for (name, field) in zip(record.names, record.values) {
                walk(field, at: steps + [.field(name)], visit)
            }

        default:
            return
        }
    }

    // The value with the place the steps reach replaced, or nil where that
    // changes more than the one place: a key replaced by one the map holds
    // already would take that entry's place too.
    private func replacing(_ steps: ArraySlice<Step>, in value: Value, with mutated: Value) -> Value? {
        guard let step = steps.first else { return mutated }

        switch (step, value) {
        case let (.position(position), .array(elements)) where elements.indices.contains(position):
            guard let element = replacing(steps.dropFirst(), in: elements[position], with: mutated) else { return nil }

            var replaced = elements
            replaced[position] = element

            return .array(replaced)

        case let (.entry(key), .dictionary(dictionary)):
            guard
                let held = dictionary[key: key],
                let entry = replacing(steps.dropFirst(), in: held, with: mutated)
            else {
                return nil
            }

            return .dictionary(dictionary.writing(key: key, with: entry))

        case let (.key(key), .dictionary(dictionary)):
            guard
                let held = dictionary[key: key],
                let replaced = replacing(steps.dropFirst(), in: key, with: mutated),
                dictionary[key: replaced] == nil
            else {
                return nil
            }

            return .dictionary(dictionary.removing(key: key).writing(key: replaced, with: held))

        case let (.field(field), .record(record)):
            guard
                let position = record.layout.position(of: field),
                let held = replacing(steps.dropFirst(), in: record.values[position], with: mutated)
            else {
                return nil
            }

            return .record(record.mapValues { name, value in name == field ? held : value })

        default:
            return nil
        }
    }
}

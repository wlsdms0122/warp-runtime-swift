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

        walk(value, at: "") { path, held in
            for mutated in self.mutations(ofPlace: held) {
                mutations.append((path, replacing(path, in: value, with: mutated)))
            }
        }

        return mutations
    }

    // How many places the value holds, which is what a walk of it reaches.
    public func places(of value: Value) -> Int {
        var places = 0

        walk(value, at: "") { _, _ in places += 1 }

        return places
    }

    // MARK: - Private
    private func mutations(ofPlace value: Value) -> [Value] {
        switch value {
        case let .int(number):
            return [.int(-1), .int(.max), .int(number &+ 1), .string("not a number")]

        case let .array(elements):
            var mutations: [Value] = [.array(elements.dropLast()), .array([]), .int(0)]

            if let first = elements.first { mutations.append(.array(elements + [first])) }

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

    private func walk(_ value: Value, at path: String, _ visit: (String, Value) -> Void) {
        visit(path, value)

        guard case let .array(elements) = value else { return }

        for (position, element) in elements.enumerated() {
            walk(element, at: path.isEmpty ? "\(position)" : "\(path).\(position)", visit)
        }
    }

    private func replacing(_ path: String, in value: Value, with mutated: Value) -> Value {
        guard !path.isEmpty else { return mutated }

        return replacing(path.split(separator: ".").map { step in Int(step) ?? 0 }, in: value, with: mutated)
    }

    private func replacing(_ positions: [Int], in value: Value, with mutated: Value) -> Value {
        guard let position = positions.first else { return mutated }
        guard case var .array(elements) = value, elements.indices.contains(position) else { return value }

        elements[position] = replacing(Array(positions.dropFirst()), in: elements[position], with: mutated)

        return .array(elements)
    }
}

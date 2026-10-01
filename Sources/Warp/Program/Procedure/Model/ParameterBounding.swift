//
//  ParameterBounding.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// What a signature holds its type parameters to: one set of bounds per
// name, or the name two mentions bound two ways and the two sets.
public enum ParameterBounding: Equatable {
    case held([Name: [Name]])
    case disagreeing(Name, [Name], [Name])

    // MARK: - Property
    // The table where one is held; nothing where the signature disagrees
    // with itself, which is refused where the signature is judged.
    public var table: [Name: [Name]] {
        guard case let .held(held) = self else { return [:] }

        return held
    }

    // The sentence a disagreement is refused with, wherever it is refused.
    public var refusal: String? {
        guard case let .disagreeing(name, one, other) = self else { return nil }

        let spelled = [one, other]
            .map { names in names.sorted().map(\.spelling).joined(separator: " & ") }
            .sorted()

        return "`some \(name)` is bounded by \(spelled[0]) in one place and \(spelled[1]) in another."
            + " One name is held to one set of bounds"
    }

    // MARK: - Initializer
    // The bounds read off every occurrence. A bare mention holds its name
    // to nothing until a bounded one says otherwise.
    public init(_ occurrences: [ParameterOccurrence]) {
        var bounds: [Name: [Name]] = [:]

        // Every set a disagreeing name was bound by, so that the two reported
        // are the two first in name order rather than the two a hash seed
        // walked first.
        var disagreeing: [Name: [[Name]]] = [:]

        for occurrence in occurrences {
            let name = occurrence.name
            let constraints = occurrence.constraints

            guard !constraints.isEmpty else {
                if bounds[name] == nil { bounds[name] = [] }

                continue
            }

            guard let held = bounds[name], !held.isEmpty else {
                bounds[name] = constraints

                continue
            }

            let sorted = constraints.sorted()

            guard held.sorted() != sorted else { continue }

            var sets = disagreeing[name] ?? [held.sorted()]

            if !sets.contains(sorted) { sets.append(sorted) }

            disagreeing[name] = sets
        }

        guard let (name, sets) = disagreeing.min(by: { one, other in one.key < other.key }) else {
            self = .held(bounds)

            return
        }

        let ordered = sets.sorted { one, other in one.lexicographicallyPrecedes(other) }

        self = .disagreeing(name, ordered[0], ordered[1])
    }

    // MARK: - Public
    // MARK: - Private
}

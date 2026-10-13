//
//  IntroducedNamesReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/13/26.
//

import Foundation
import Warp

// A list that introduces names, each beside the contracts it is bounded by
// where it is bounded: a struct's `typeParameters`, `["K: Hashable", "V"]`,
// and a contract's `types`, `["Item: Hashable"]`. A name is bounded where it
// is introduced, so this is the one place either writes a bound.
struct IntroducedNamesReader {
    // MARK: - Property
    // The names in the order written, and the bound each written one names.
    let names: [Name]
    let bounds: [Name: Set<Name>]

    // MARK: - Initializer
    init(reading decoder: Decoder) throws {
        var names: [Name] = []
        var bounds: [Name: Set<Name>] = [:]

        for (position, entry) in try decoder.read([ValueReader].self).map(\.value).enumerated() {
            let steps = decoder.steps + [.index(position)]

            guard case let .string(written) = entry else {
                throw ReadingError(
                    "is an entry of a list that introduces names, and one is a name, or a name and what bounds it"
                        + " written as one string, `\"K: Hashable\"`",
                    at: steps
                )
            }

            let parts = written.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let name = try Name.read(parts[0].trimmingCharacters(in: Path.whiteSpace), at: steps)

            // One name introduced twice would be one name bounded two ways.
            guard !names.contains(name) else {
                throw ReadingError("lists '\(name)' twice", at: steps)
            }

            names.append(name)

            guard parts.count > 1 else { continue }

            let bound = parts[1].trimmingCharacters(in: Path.whiteSpace)

            do {
                bounds[name] = try TypeReader.contracts(bound, in: decoder.notation)
            } catch let refused as TypeFormError {
                throw ReadingError("bounds '\(name)' by '\(bound)': \(refused.message)", at: steps)
            }
        }

        self.names = names
        self.bounds = bounds
    }

    // MARK: - Public
    // MARK: - Private
}

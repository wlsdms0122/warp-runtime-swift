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

        for (position, written) in try decoder.read([String].self).enumerated() {
            let steps = decoder.steps + [.index(position)]
            let parts = written.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let name = try Name.read(parts[0].trimmingCharacters(in: Path.whiteSpace), at: steps)

            names.append(name)

            guard parts.count > 1 else { continue }

            do {
                bounds[name] = try TypeReader.contracts(String(parts[1]), in: decoder.notation)
            } catch let refused as TypeFormError {
                throw ReadingError("bounds '\(name)' by '\(parts[1])': \(refused.message)", at: steps)
            }
        }

        self.names = names
        self.bounds = bounds
    }

    // MARK: - Public
    // MARK: - Private
}

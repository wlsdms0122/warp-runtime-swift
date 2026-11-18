//
//  Value+Divergence.swift
//  WarpSyntax
//
//  Created by JSilver on 9/24/26.
//

import Foundation
import Warp

// Where two values first part, for a reading holding a document against the
// one spelling of what it says.
extension Value {
    // The steps down to the first place this and `other` hold different
    // things, walked in key order, with what `other` writes there, or nil
    // where they are one value. A key this has and `other` does not is a place
    // `other` writes nothing, and a key `other` has and this does not is
    // written at the dictionary, as that key. A struct's name is a place they
    // part too.
    func divergence(from other: Value) throws -> (steps: [Place.Step], written: String)? {
        guard nominal == other.nominal else { return ([], try Self.line(other)) }

        if case let .dictionary(mine) = self, case let .dictionary(theirs) = other {
            let keys = try theirs.keys.reduce(mine) { both, key in try both.writing(key: key, with: .null) }.keys

            for key in keys {
                guard let held = mine[key: key] else {
                    return ([], "the key \(try Self.line(key)) here")
                }

                let step = Place.Step.key(Rendering(key).text())

                guard let written = theirs[key: key] else {
                    return ([step], "nothing")
                }

                if let below = try held.divergence(from: written) {
                    return ([step] + below.steps, below.written)
                }
            }

            return nil
        }

        if case let .array(mine) = self, case let .array(theirs) = other {
            for (position, (held, written)) in zip(mine, theirs).enumerated() {
                if let below = try held.divergence(from: written) {
                    return ([.index(position)] + below.steps, below.written)
                }
            }

            guard mine.count == theirs.count else {
                let position = min(mine.count, theirs.count)

                return (
                    [.index(position)],
                    theirs.indices.contains(position) ? try Self.line(theirs[position]) : "nothing"
                )
            }

            return nil
        }

        return self == other ? nil : ([], try Self.line(other))
    }

    // MARK: - Private
    private static func line(_ value: Value) throws -> String {
        try TextEncoding().line(from: value)
    }
}

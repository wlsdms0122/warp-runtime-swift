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
    // things, walked in key order, with what `other` holds there, or nil
    // where they are one value. A key one side has and the other does not is
    // a place they part, and so is a struct's name.
    func divergence(from other: Value) -> (steps: [Place.Step], held: Value?)? {
        guard nominal == other.nominal else { return ([], other) }

        if case let .dictionary(mine) = self, case let .dictionary(theirs) = other {
            let keys = theirs.keys.reduce(mine) { both, key in both.writing(key: key, with: .null) }.keys

            for key in keys {
                let step = Place.Step.key(Rendering(key).text())

                guard let held = mine[key: key], let written = theirs[key: key] else {
                    return ([step], theirs[key: key])
                }

                if let below = held.divergence(from: written) {
                    return ([step] + below.steps, below.held)
                }
            }

            return nil
        }

        if case let .array(mine) = self, case let .array(theirs) = other {
            for (position, (held, written)) in zip(mine, theirs).enumerated() {
                if let below = held.divergence(from: written) {
                    return ([.index(position)] + below.steps, below.held)
                }
            }

            guard mine.count == theirs.count else {
                let position = min(mine.count, theirs.count)

                return ([.index(position)], theirs.indices.contains(position) ? theirs[position] : nil)
            }

            return nil
        }

        return self == other ? nil : ([], other)
    }
}

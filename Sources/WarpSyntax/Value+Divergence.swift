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
    // things, walked in key order, or nil where they are one value. A key one
    // side has and the other does not is a place they part. A record is
    // walked as the mapping it is, whichever side holds one.
    func divergence(from other: Value) -> [Place.Step]? {
        if let mine = asDictionary, let theirs = other.asDictionary {
            for name in Set(mine.names).union(theirs.names).sorted() {
                guard let held = mine[name], let written = theirs[name] else { return [.key(name.spelling)] }

                if let below = held.divergence(from: written) { return [.key(name.spelling)] + below }
            }

            return nil
        }

        if case let .array(mine) = self, case let .array(theirs) = other {
            for (position, (held, written)) in zip(mine, theirs).enumerated() {
                if let below = held.divergence(from: written) { return [.index(position)] + below }
            }

            return mine.count == theirs.count ? nil : [.index(min(mine.count, theirs.count))]
        }

        return self == other ? nil : []
    }

    // What stands at those steps, written on one line, or `nothing` where
    // nothing does.
    func spelled(at steps: [Place.Step]) -> String {
        var held: Value? = self

        for step in steps {
            switch step {
            case let .key(key):
                held = (try? Name(key)).flatMap { name in held?.asDictionary?[name] }

            case let .index(position):
                guard case let .array(elements)? = held, elements.indices.contains(position) else { return "nothing" }

                held = elements[position]

            default:
                return "nothing"
            }
        }

        guard let held, let text = try? TextEncoding.text(from: held) else { return "nothing" }

        return text
            .split(separator: "\n")
            .dropFirst()
            .map { line in line.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }
}

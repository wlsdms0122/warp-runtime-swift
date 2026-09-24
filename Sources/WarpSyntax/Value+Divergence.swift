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
    // side has and the other does not is a place they part.
    func divergence(from other: Value) -> [Place.Step]? {
        switch (self, other) {
        case let (.dictionary(mine), .dictionary(theirs)):
            for name in Set(mine.names).union(theirs.names).sorted() {
                guard let held = mine[name], let written = theirs[name] else { return [.key(name.spelling)] }

                if let below = held.divergence(from: written) { return [.key(name.spelling)] + below }
            }

            return nil

        case let (.array(mine), .array(theirs)):
            for (position, (held, written)) in zip(mine, theirs).enumerated() {
                if let below = held.divergence(from: written) { return [.index(position)] + below }
            }

            return mine.count == theirs.count ? nil : [.index(min(mine.count, theirs.count))]

        default:
            return self == other ? nil : []
        }
    }
}

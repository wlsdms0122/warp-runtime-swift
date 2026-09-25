//
//  Step.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A path segment as the run reads it. An index written as a name is the slot
// path it reads the position from.
enum Step: Sendable {
    // A field of a record whose layout the link proved: the place it stands
    // in, which is where a read and a write both land, beside the spelling
    // the path wrote, which is what a sentence calls it.
    case field(Int, Name, optional: Bool)

    // A name read from what only the run knows the keys of: a dictionary, or
    // a value that arrived through `any`.
    case key(Name, optional: Bool)

    case index(Int, optional: Bool)
    case at(Address, optional: Bool)

    var optional: Bool {
        switch self {
        case let .field(_, _, optional), let .key(_, optional), let .index(_, optional),
            let .at(_, optional):
            return optional
        }
    }
}

extension Step {
    func reads(_ slots: Range<Int>) -> Bool {
        guard case let .at(address, _) = self else { return false }

        return address.reads(slots)
    }
}

//
//  Step.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A path segment as the run reads it. A word is the row it sends, kept
// with the spelling the path wrote so a refusal reads back as written, and
// an index written as a name is the slot path it reads the position from.
enum Step: Sendable {
    case key(Name, optional: Bool)
    case index(Int, optional: Bool)
    case at(Int, [Step], optional: Bool)
    case word(Int, Name, optional: Bool)

    var optional: Bool {
        switch self {
        case let .key(_, optional), let .index(_, optional),
            let .at(_, _, optional), let .word(_, _, optional):
            return optional
        }
    }
}

extension Step {
    func reads(_ slots: Range<Int>) -> Bool {
        guard case let .at(slot, steps, _) = self else { return false }

        return slots.contains(slot) || steps.contains { step in step.reads(slots) }
    }
}

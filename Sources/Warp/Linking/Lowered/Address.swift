//
//  Address.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Where a path lands in a frame: the slot it starts at, and the steps from
// there. A read of a name is one, a write names one, an index written as a
// name reads one, and a parameter handed in place is the caller's.
//
// One type because the four are one act. Every fact the link works out about
// reaching a name (which slot, which of a record's places, which row a word
// sends) is worked out once and read from here, rather than spelled again
// wherever a path is written.
struct Address: Sendable {
    // MARK: - Property
    let slot: Int
    let steps: [Step]

    // MARK: - Initializer
    init(slot: Int, steps: [Step]) {
        self.slot = slot
        self.steps = steps
    }

    // MARK: - Public
    // Whether reaching here reads any slot in the range, through the index
    // references among the steps as well as through the head.
    func reads(_ slots: Range<Int>) -> Bool {
        slots.contains(slot) || steps.contains { step in step.reads(slots) }
    }

    // MARK: - Private
}

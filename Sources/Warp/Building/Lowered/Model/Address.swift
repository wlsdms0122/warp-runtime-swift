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
// One type because the four are one act. Every fact the build works out about
// reaching a name (which slot, which of a struct's places, which row a procedure
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
    func stand(in standing: inout LoweredBody.Standing) {
        standing.stand(on: slot)
        steps.forEach { step in step.stand(in: &standing) }
    }

    // MARK: - Private
}

//
//  Leaving.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// A run on its way somewhere further out.
//
// It travels the way a failure does because the type is the same (everything
// between here and where it lands is abandoned) but it is not a failure, and
// the difference is load-bearing: `attempt` catches what the world did, and
// this is what the program said. Leaving a body an `attempt` was watching runs
// no rescue, and an observer is told of no failure.
//
// Nothing catches it but the construct it names. A document may only write one
// that something around it will catch, which the load holds before
// anything runs; an object carries the lowered body rather than the document,
// so the edge of a frame answers one that reaches it.
struct Leaving: Error {
    // MARK: - Property
    let reach: Leave.Reach
    let target: Name?

    // What a procedure answers by leaving. A loop answers nothing, so this is
    // nothing for the other two reaches.
    let value: Value

    // MARK: - Initializer
    init(reach: Leave.Reach, target: Name?, value: Value = .null) {
        self.reach = reach
        self.target = target
        self.value = value
    }

    // MARK: - Public
    // Whether a loop should take this. An unnamed one is for the nearest, so the
    // first loop it reaches answers it; a named one passes through every loop
    // but the one it named, a nameless loop included.
    func claimed(by round: Name?) -> Bool {
        guard reach != .procedure else { return false }

        return target == nil || target == round
    }

    // MARK: - Private
}

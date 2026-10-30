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
// the difference is load-bearing: `try` catches what the world did, and
// this is what the program said. Leaving a body a `try` was watching runs
// no catch, and an observer is told of no failure.
//
// Nothing catches it but the construct it names. A document may only write one
// that something around it will catch, which the load holds before
// anything runs; an object carries the lowered body rather than the document,
// so the edge of a frame catches one that reaches it.
enum Leaving: Error {
    // A `return`, with what the procedure returns.
    case procedure(Value)

    // A `break` and a `continue`, with the loop each names, or nothing for
    // the nearest.
    case loop(Name?)
    case round(Name?)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Whether a loop should take this. An unnamed one is for the nearest, so the
    // first loop it reaches takes it; a named one passes through every loop
    // but the one it named, a nameless loop included.
    func claimed(by round: Name?) -> Bool {
        switch self {
        case .procedure: false
        case let .loop(target), let .round(target): target == nil || target == round
        }
    }

    // MARK: - Private
}

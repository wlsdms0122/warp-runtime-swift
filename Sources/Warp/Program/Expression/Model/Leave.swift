//
//  Leave.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// Stopping where you are and carrying on somewhere further out. Whether one
// is allowed depends on what it is written inside: what the procedure around
// `return` declared it answers, and a loop around `break` and `continue`.
// The three differ in how far they go and in nothing else.
public struct Leave: Sendable {
    // How far out. `procedure` answers, and the other two are about a loop:
    // `construct` ends it, `round` ends the round it is in.
    public enum Reach: Sendable, Hashable {
        case procedure
        case construct
        case round
    }

    // MARK: - Property
    public let reach: Reach

    // Which loop, where more than one encloses this. Nothing means the nearest,
    // the way it does everywhere else. A name is for reaching past it.
    public let target: Name?

    // What a procedure answers by leaving. Only `procedure` carries one: a loop
    // answers what it was going to answer, so ending one early asks nothing new
    // of the type it has.
    public let value: Expression?

    // MARK: - Initializer
    public init(reach: Reach, target: Name? = nil, value: Expression? = nil) {
        self.reach = reach
        self.target = target
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}

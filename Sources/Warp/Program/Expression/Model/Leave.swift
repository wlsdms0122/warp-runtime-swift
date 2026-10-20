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
// The three differ in how far they go and in what they carry.
public enum Leave: Sendable {
    // How far out. `procedure` answers, and the other two are about a loop:
    // `construct` ends it, `round` ends the round it is in.
    public enum Reach: Sendable, Hashable {
        case procedure
        case construct
        case round
    }

    // A `return`, with what the procedure answers, or nothing for null.
    case procedure(Expression?)

    // A `break` and a `continue`, with the loop they end, or nothing for the
    // nearest, the way it is everywhere else. A name is for reaching past
    // it. A loop answers nothing, so ending one carries nothing.
    case construct(Name?)
    case round(Name?)

    // MARK: - Property
    var reach: Reach {
        switch self {
        case .procedure: .procedure
        case .construct: .construct
        case .round: .round
        }
    }

    // Which loop a `break` or a `continue` names.
    var target: Name? {
        switch self {
        case .procedure: nil
        case let .construct(target), let .round(target): target
        }
    }

    // What a `return` carries.
    var value: Expression? {
        guard case let .procedure(value) = self else { return nil }

        return value
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

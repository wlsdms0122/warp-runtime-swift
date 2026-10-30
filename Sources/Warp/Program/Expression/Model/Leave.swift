//
//  Leave.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// Stopping where you are and carrying on somewhere further out. Whether one
// is allowed depends on what it is written inside: what the procedure around
// `return` declared it returns, and a loop around `break` and `continue`.
// The three differ in how far they go and in what they carry.
public enum Leave: Sendable {
    // How far out. `procedure` returns, and the other two are about a loop:
    // `loop` ends it, `round` ends the round it is in.
    public enum Reach: Sendable, Hashable {
        case procedure
        case loop
        case round
    }

    // A `return`, with what the procedure returns, or nothing for null.
    case procedure(Expression?)

    // A `break` and a `continue`, with the loop they end, or nothing for the
    // nearest, the way it is everywhere else. A name is for reaching past
    // it. A loop has no value, so ending one carries nothing.
    case loop(Name?)
    case round(Name?)

    // MARK: - Property
    var reach: Reach {
        switch self {
        case .procedure: .procedure
        case .loop: .loop
        case .round: .round
        }
    }

    // Which loop a `break` or a `continue` names.
    var target: Name? {
        switch self {
        case .procedure: nil
        case let .loop(target), let .round(target): target
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

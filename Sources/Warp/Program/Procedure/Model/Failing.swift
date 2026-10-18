//
//  Failing.swift
//  Warp
//
//  Created by JSilver on 9/6/26.
//

import Foundation

// What may come out of a body or a procedure when the work itself goes wrong:
// the types a `RecoverableFailure` names itself by, which is what a rescue
// reads as `type`.
//
// Declared by a signature and a procedure type; a body is held to what its
// declaration says by what it casts, calls and rescues.
public enum Failing: Sendable, Equatable {
    // Anything at all.
    case anything

    // These and no others. The empty set is a body nothing can fail out of.
    case these(Set<String>)

    // MARK: - Property
    // Whether this says nothing can fail out of it.
    public var failsNothing: Bool {
        self == .these([])
    }

    // How a refusal names it: the failures in order, nothing, or anything.
    public var rendered: String {
        switch self {
        case .anything:
            return "anything"

        case let .these(failures) where failures.isEmpty:
            return "nothing"

        case let .these(failures):
            return failures.sorted().map { failure in "'\(failure)'" }.joined(separator: ", ")
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // What may come out of one and then the other: anything where either
    // may fail with anything.
    public func joined(_ other: Failing) -> Failing {
        guard case let .these(mine) = self, case let .these(theirs) = other else { return .anything }

        return .these(mine.union(theirs))
    }

    // Whether everything this may fail with is among `allowed`. Anything is
    // within no list.
    public func fails(within allowed: Set<String>) -> Bool {
        guard case let .these(failures) = self else { return false }

        return failures.isSubset(of: allowed)
    }

    // Whether this stands where a slot says `allowed` may come out: anywhere
    // a slot allows anything, and within what it names otherwise.
    func fails(within allowed: Failing) -> Bool {
        guard case let .these(names) = allowed else { return true }

        return fails(within: names)
    }

    // MARK: - Private
}

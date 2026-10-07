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
// Derived for a body from what it casts, calls and rescues; declared by a
// native procedure, which is the only one that can say. One that says nothing
// fails nothing: the judge reads the empty set for it.
public enum Failing: Sendable, Equatable {
    // No claim. What comes out of this is not knowable before the run.
    case unstated

    // These and no others. The empty set is a body nothing can fail out of.
    case these(Set<String>)

    // MARK: - Property
    // Whether this says nothing can fail out of it. A claim, so an unstated
    // one answers false.
    public var failsNothing: Bool {
        self == .these([])
    }

    // How a refusal names it: the failures in order, nothing, or anything
    // where nothing was claimed.
    public var rendered: String {
        switch self {
        case .unstated:
            return "anything"

        case let .these(failures) where failures.isEmpty:
            return "nothing"

        case let .these(failures):
            return failures.sorted().map { failure in "'\(failure)'" }.joined(separator: ", ")
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // What may come out of one and then the other. Unstated on either side
    // carries: an unknown joined with anything is still unknown.
    public func joined(_ other: Failing) -> Failing {
        guard case let .these(mine) = self, case let .these(theirs) = other else { return .unstated }

        return .these(mine.union(theirs))
    }

    // Whether everything this may fail with is among `allowed`. An unstated
    // one may fail with anything, so it is within no list.
    public func fails(within allowed: Set<String>) -> Bool {
        guard case let .these(failures) = self else { return false }

        return failures.isSubset(of: allowed)
    }

    // MARK: - Private
}

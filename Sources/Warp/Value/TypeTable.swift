//
//  TypeTable.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The type table: every shape the modules in a link declared, and what each name
// stands for. The counterpart of `Library` on the other axis — that one holds
// the words a caller installed, this one the shapes a document declared.
//
// It exists because a named type is kept rather than expanded. Expanding at link
// would make a self-naming shape a regress, so the name survives into the run and
// something has to be able to answer it.
//
// Constraints live beside the types rather than among them. A constraint is a
// name for a membership — which types a bounded parameter admits — and nothing
// is ever *of* one, so a slot cannot declare it and a value cannot arrive as
// it. Two tables keep the two questions apart: "what shape is this name" and
// "what does this name admit".
public struct TypeTable: Sendable {
    // MARK: - Property
    public private(set) var types: [String: TypeExpression]
    public private(set) var constraints: [String: [TypeExpression]]

    // MARK: - Initializer
    public init(
        types: [String: TypeExpression] = [:],
        constraints: [String: [TypeExpression]] = [:]
    ) {
        self.types = types
        self.constraints = constraints
    }

    // MARK: - Public
    public func resolve(_ name: String) -> TypeExpression? {
        types[name]
    }

    public func constraint(_ name: String) -> [TypeExpression]? {
        constraints[name]
    }

    // Whether a reading could be a member of a constraint, or nil when nothing
    // declares the name — the caller says what an undeclared constraint means
    // on its surface, rather than this deciding for both. Membership is
    // one-sided the way every judgment before the run is: only what is
    // provably outside is refused, and a reading nothing can be said about —
    // `any`, or another type parameter with no constraint of its own — passes
    // here and is judged again where the value actually arrives.
    //
    // A constrained reading is judged by its own membership rather than by its
    // name: it stands for some member of its constraint, so it fits where
    // every one of those members would. The table ends its own recursion — a
    // membership already being asked answers yes rather than being asked
    // again — so a table built by hand refuses or answers where a linked one
    // would, and never chases a declaration the link would have refused.
    public func admits(constraint name: String, reading: TypeExpression) -> Bool? {
        admits(constraint: name, reading: reading, assuming: [])
    }

    // The same membership, asked of a value at the boundary — nil again when
    // nothing declares the name. A member speaks through the same settlement a
    // declared type applies, so what `int` admits as a slot it admits as a
    // member, widening included. The settlement carries which constraints are
    // already being asked, so this side ends its own recursion the way the
    // reading side does.
    public func admits(constraint name: String, value: Value) -> Bool? {
        admits(constraint: name, value: value, assuming: [])
    }

    func admits(constraint name: String, value: Value, assuming: Set<String>) -> Bool? {
        guard let members = constraints[name] else { return nil }

        return members.contains { member in
            (try? member.settling(value, at: "member", in: self, assuming: assuming)) != nil
        }
    }

    // MARK: - Private
    private func admits(
        constraint name: String,
        reading: TypeExpression,
        assuming: Set<String>
    ) -> Bool? {
        guard let members = constraints[name] else { return nil }

        switch reading {
        case .any:
            return true

        // Filled by a call, so it proves no membership here — said by name
        // beside the parameter it is the walk-through of, rather than left to
        // what `accepts` happens to answer.
        case .reading:
            return true

        case let .variable(_, constraint):
            guard let constraint, let inner = constraints[constraint] else { return true }
            guard !assuming.contains(constraint) else { return true }

            return inner.allSatisfy { member in
                admits(
                    constraint: name,
                    reading: member,
                    assuming: assuming.union([constraint])
                ) == true
            }

        default:
            return members.contains { member in member.accepts(reading, in: self) }
        }
    }
}

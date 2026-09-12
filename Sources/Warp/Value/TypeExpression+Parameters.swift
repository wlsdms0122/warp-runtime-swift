//
//  TypeExpression+Parameters.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The type parameters a declaration writes: which names it mentions, what each
// is bounded by, and whether it has any at all. What a call puts in them is
// read off the lowered declaration, where the readings are.
extension TypeExpression {
    // Every type parameter mentioned in here, each with the constraint names
    // carried on it. A set per name, because occurrences carry the bound
    // separately: `some T` bounded in one slot and bare in another are one
    // parameter bounded once, and two occurrences carrying different
    // constraints are two claims about one name. A disagreement the link
    // refuses rather than picks from.
    func parameterConstraints(into table: inout [Name: Set<Name>]) {
        switch self {
        case let .parameter(name, constraint):
            table[name, default: []].formUnion(constraint.map { bound in [bound] } ?? [])

        // Not a slot a signature declares, and it carries no bound to claim.
        // There is nothing here for a `bounds` to speak for.
        case .reading:
            return

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            element.parameterConstraints(into: &table)

        case let .record(fields):
            for field in fields.values {
                field.parameterConstraints(into: &table)
            }

        case let .procedure(signature, _, _):
            signature?.parameterConstraints(into: &table)

        case let .variable(inner), let .inout(inner):
            inner.parameterConstraints(into: &table)

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read the way it always was, so nothing pays for a feature it does not
    // use.
    var isGeneric: Bool {
        switch self {
        // Both are types a call decides, and the deep question is only
        // whether this declaration has to be filled at all.
        case .parameter, .reading:
            return true

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            return element.isGeneric

        case let .record(fields):
            return fields.values.contains { field in field.isGeneric }

        case let .procedure(signature, _, _):
            return signature?.isGeneric ?? false

        case let .variable(inner), let .inout(inner):
            return inner.isGeneric

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return false
        }
    }
}

public extension Signature {
    var isGeneric: Bool {
        parameters.values.contains { parameter in parameter.declared.isGeneric }
            || (returns?.isGeneric ?? false)
    }

    // The type parameters this signature declares, by mention, with every
    // constraint name written on each. One name may be mentioned bare and
    // bounded; the bound mention speaks for both.
    //
    // A nested signature's parameters merge into the same table on purpose.
    // They are this signature's own slots: `map` takes `array<some Element>`
    // beside a procedure whose `item` is the same `some Element`, and it is one
    // parameter filled by one call. Only a parameter behind a `named` type is
    // not collected, because the link refuses one anywhere but a procedure
    // signature and never fills one through the name.
    func parameterConstraints(into table: inout [Name: Set<Name>]) {
        for parameter in parameters.values {
            parameter.declared.parameterConstraints(into: &table)
        }

        returns?.parameterConstraints(into: &table)
    }

    // This signature with each type parameter's occurrences carrying the
    // constraint declared for its name. The signature owns the bound and the
    // occurrences read it. A notation writes `bounds: { N: Numeric }` once and
    // `some N` in the slots, and this is where the one meets the many.
    //
    // An occurrence already carrying a bound keeps it: a nested signature may
    // have declared its own, and overwriting would silently pick between two
    // claims the link refuses out loud.
    func bounded(by bounds: [Name: Name]) -> Signature {
        guard !bounds.isEmpty else { return self }

        return Signature(
            receiver: receiver,
            parameters: parameters.mapValues { parameter in
                Parameter(
                    type: parameter.type?.bounded(by: bounds),
                    candidates: parameter.candidates,
                    default: parameter.default,
                    description: parameter.description
                )
            },
            returns: returns?.bounded(by: bounds)
        )
    }
}

extension TypeExpression {
    // The occurrence side of `Signature.bounded(by:)`, walked through every
    // place a type parameter may sit. A nested signature's parameters included,
    // because they are the outer signature's own slots.
    func bounded(by bounds: [Name: Name]) -> TypeExpression {
        switch self {
        case let .parameter(name, constraint):
            return .parameter(name: name, constraint: constraint ?? bounds[name])

        case .reading:
            return self

        case let .linear(inner):
            return .linear(inner.bounded(by: bounds))

        case let .array(element):
            return .array(element.bounded(by: bounds))

        case let .dictionary(entry):
            return .dictionary(entry.bounded(by: bounds))

        case let .record(fields):
            return .record(fields.mapValues { field in field.bounded(by: bounds) })

        case let .procedure(signature, purity, isolation):
            return .procedure(signature?.bounded(by: bounds), purity, isolation)

        case let .nullable(inner):
            return .nullable(inner.bounded(by: bounds))

        case let .variable(inner):
            return .variable(inner.bounded(by: bounds))

        case let .inout(inner):
            return .inout(inner.bounded(by: bounds))

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return self
        }
    }
}

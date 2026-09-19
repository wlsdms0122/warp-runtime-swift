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
    // Every type parameter mentioned in here, occurrence by occurrence, with
    // the constraint names that occurrence carries.
    func parameterOccurrences(_ visit: (Name, [Name]) -> Void) {
        switch self {
        case let .parameter(name, constraints):
            visit(name, constraints)

        case .reading, .composition:
            return

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            element.parameterOccurrences(visit)

        case let .record(fields):
            for field in fields.values {
                field.parameterOccurrences(visit)
            }

        case let .procedure(signature, _, _):
            signature?.parameterOccurrences(visit)

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            inner.parameterOccurrences(visit)

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

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return inner.isGeneric

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named, .composition:
            return false
        }
    }
}

public extension Signature {
    var isGeneric: Bool {
        parameters.values.contains { parameter in parameter.declared.isGeneric }
            || (returns?.isGeneric ?? false)
    }

    // The bounds each type parameter this signature declares is held to: the
    // set a bounded mention carries, or none where every mention is bare.
    // What a signature holds a name to is one set, so two mentions carrying
    // two sets are two claims about one name, and this says which name.
    //
    // A nested signature's parameters merge into the same table on purpose.
    // They are this signature's own slots: `map` takes `array<some Element>`
    // beside a procedure whose `item` is the same `some Element`, and it is one
    // parameter filled by one call. Only a parameter behind a `named` type is
    // not collected, because the link refuses one anywhere but a procedure
    // signature and never fills one through the name.
    var parameterBounds: ParameterBounds {
        var bounds: [Name: [Name]] = [:]
        var disagreeing: (name: Name, sets: [[Name]])?

        parameterOccurrences { name, constraints in
            guard let held = bounds[name], !held.isEmpty, !constraints.isEmpty else {
                if !constraints.isEmpty || bounds[name] == nil {
                    bounds[name] = constraints
                }

                return
            }

            if disagreeing == nil, held.sorted() != constraints.sorted() {
                disagreeing = (name, [held, constraints])
            }
        }

        guard let disagreeing else { return .held(bounds) }

        return .disagreeing(disagreeing.name, disagreeing.sets)
    }

    // Every type parameter mentioned in this signature, occurrence by
    // occurrence, with the constraint names that occurrence carries.
    func parameterOccurrences(_ visit: (Name, [Name]) -> Void) {
        for parameter in parameters.values {
            parameter.declared.parameterOccurrences(visit)
        }

        returns?.parameterOccurrences(visit)
    }

    // This signature with each type parameter's occurrences carrying the
    // constraint declared for its name. The signature owns the bound and the
    // occurrences read it. A notation writes `bounds: { N: Numeric }` once and
    // `some N` in the slots, and this is where the one meets the many.
    //
    // An occurrence already carrying a bound keeps it: a nested signature may
    // have declared its own, and overwriting would silently pick between two
    // claims the link refuses out loud.
    func bounded(by bounds: [Name: [Name]]) -> Signature {
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
    func bounded(by bounds: [Name: [Name]]) -> TypeExpression {
        switch self {
        case let .parameter(name, constraints):
            return .parameter(name: name, constraints: constraints.isEmpty ? bounds[name] ?? [] : constraints)

        case .reading, .composition:
            return self

        case let .linear(inner):
            return .linear(inner.bounded(by: bounds))

        case let .array(element):
            return .array(element.bounded(by: bounds))

        case let .dictionary(entry):
            return .dictionary(entry.bounded(by: bounds))

        case let .record(fields):
            return .record(fields.mapValues { field in field.bounded(by: bounds) })

        case let .procedure(signature, constness, isolation):
            return .procedure(signature?.bounded(by: bounds), constness, isolation)

        case let .nullable(inner):
            return .nullable(inner.bounded(by: bounds))

        case let .variable(inner):
            return .variable(inner.bounded(by: bounds))

        case let .inout(inner):
            return .inout(inner.bounded(by: bounds))

        case let .consuming(inner):
            return .consuming(inner.bounded(by: bounds))

        case let .borrowing(inner):
            return .borrowing(inner.bounded(by: bounds))

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return self
        }
    }
}

public extension Signature {
    // What a signature holds its type parameters to: one set of bounds per
    // name, or the name two mentions bound two ways and the two sets.
    enum ParameterBounds: Equatable {
        case held([Name: [Name]])
        case disagreeing(Name, [[Name]])

        // The two sets, spelled for a sentence saying they differ.
        public static func spelled(_ sets: [[Name]]) -> String {
            sets
                .map { names in names.sorted().map(\.spelling).joined(separator: " & ") }
                .sorted()
                .joined(separator: " in one place and ")
        }
    }
}

//
//  LoweredType+Renumbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

extension LoweredType {
    // The same type with every row it stands on answered again. A type is a
    // tree and its rows stand at the leaves, so a caller that can answer one
    // number answers the whole of it, and the walk over the tree is written
    // once.
    //
    // Two answers, because a type names two tables. A declared type and a
    // membership are separate spaces and no name is in both, so which of them
    // a number counts in is a fact of the case it stands in.
    // Which rows of a link this type stands on, in the two tables it names.
    // Read by answering every number with itself, so the walk over the tree
    // stays written once.
    func standing(into types: inout Set<Int>, and memberships: inout Set<Int>) {
        _ = renumbered(
            type: { row in
                types.insert(row)

                return row
            },
            membership: { row in
                memberships.insert(row)

                return row
            }
        )
    }

    func renumbered(
        type: (Int) throws -> Int,
        membership: (Int) throws -> Int
    ) rethrows -> LoweredType {
        switch self {
        case let .array(element):
            return .array(try element.renumbered(type: type, membership: membership))

        case let .dictionary(entry):
            return .dictionary(try entry.renumbered(type: type, membership: membership))

        case let .record(held):
            return .record(
                LoweredRecord(
                    layout: held.layout,
                    fields: try held.fields.map { field in
                        try field.renumbered(type: type, membership: membership)
                    }
                )
            )

        case let .procedure(parameters, returns, constness, isolation):
            return .procedure(
                parameters: try parameters?.map { parameter in
                    LoweredParameter(
                        name: parameter.name,
                        type: try parameter.type.renumbered(type: type, membership: membership),
                        mustBeGiven: parameter.mustBeGiven
                    )
                },
                returns: try returns?.renumbered(type: type, membership: membership),
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(try inner.renumbered(type: type, membership: membership))

        case let .inout(inner):
            return .inout(try inner.renumbered(type: type, membership: membership))

        case let .nullable(inner):
            return .nullable(try inner.renumbered(type: type, membership: membership))

        case let .named(row):
            return .named(try type(row))

        case let .parameter(label, bounds):
            return .parameter(label: label, bounds: try bounds.renumbered(membership: membership))

        case let .composition(bounds):
            return .composition(try bounds.renumbered(membership: membership))

        // Every case that stands on no row, listed rather than let through:
        // a case added here has to say whether it holds one.
        case .any, .never, .null, .bool, .int, .double, .string, .bytes,
            .ranged, .reading, .undeclared:
            return self
        }
    }
}

extension Array where Element == LoweredType.Bound {
    // The same bounds over the rows the transform answers: a membership
    // stands on a row and a contract on a name. Sorted again, since the
    // order is the rows' and the rows moved.
    func renumbered(membership: (Int) throws -> Int) rethrows -> [LoweredType.Bound] {
        try map { bound in
            guard case let .membership(row) = bound else { return bound }

            return .membership(try membership(row))
        }
        .sorted()
    }
}

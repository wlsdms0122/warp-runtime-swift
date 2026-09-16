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
                    (
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

        case let .member(row):
            return .member(try membership(row))

        case let .parameter(label, bound):
            guard case let .membership(row)? = bound else { return self }

            return .parameter(label: label, bound: .membership(try membership(row)))

        // Every case that stands on no row, listed rather than let through:
        // a case added here has to say whether it holds one.
        case .any, .never, .null, .bool, .int, .double, .string, .bytes, .number,
            .ranged, .reading, .undeclared:
            return self
        }
    }
}

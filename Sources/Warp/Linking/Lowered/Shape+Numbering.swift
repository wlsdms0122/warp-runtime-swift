//
//  Shape+Numbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

extension Shape {
    // The same shape with every row it stands on answered again. A shape is a
    // tree and its rows stand at the leaves, so a caller that can answer one
    // number answers the whole of it, and the walk over the tree is written
    // once.
    //
    // Two answers, because a shape names two tables. A declared type and a
    // membership are separate spaces and no name is in both, so which of them
    // a number counts in is a fact of the case it stands in.
    func renumbered(
        type: (Int) throws -> Int,
        membership: (Int) throws -> Int
    ) rethrows -> Shape {
        switch self {
        case let .array(element):
            return .array(try element.renumbered(type: type, membership: membership))

        case let .dictionary(entry):
            return .dictionary(try entry.renumbered(type: type, membership: membership))

        case let .record(held):
            return .record(
                RecordShape(
                    layout: held.layout,
                    fields: try held.fields.map { field in
                        try field.renumbered(type: type, membership: membership)
                    }
                )
            )

        case let .procedure(parameters, returns, purity, isolation):
            return .procedure(
                parameters: try parameters?.map { parameter in
                    (
                        name: parameter.name,
                        shape: try parameter.shape.renumbered(type: type, membership: membership),
                        mustBeGiven: parameter.mustBeGiven
                    )
                },
                returns: try returns?.renumbered(type: type, membership: membership),
                purity: purity,
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

        default:
            return self
        }
    }
}

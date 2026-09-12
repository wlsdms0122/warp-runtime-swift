//
//  TypeExpression+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension TypeExpression {
    // This type as the run reads it, with every name resolved to its row. A
    // name nothing declares lowers to the type every judgment refuses, so
    // lowering is total and a table a host built by hand still answers for
    // every other name in it.
    func lowered(in table: LoweredTypeTable) -> LoweredType {
        switch self {
        case .any:
            return .any

        case .never:
            return .never

        case .null:
            return .null

        case .bool:
            return .bool

        case .int:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case .bytes:
            return .bytes

        case .number:
            return .number

        case let .ranged(refinement):
            return .ranged(refinement)

        case let .array(element):
            return .array(element.lowered(in: table))

        case let .dictionary(entry):
            return .dictionary(entry.lowered(in: table))

        case let .record(fields):
            let ordered = fields.sorted { left, right in left.key < right.key }

            return .record(
                LoweredRecord(
                    layout: Layout(name: nil, ordered: ordered.map(\.key)),
                    fields: ordered.map { _, field in field.lowered(in: table) }
                )
            )

        case let .procedure(signature, purity, isolation):
            return .procedure(
                parameters: signature?.ordered(
                    { name, parameter in
                        let lowered = parameter.declared.lowered(in: table)

                        return (
                            name: name,
                            type: lowered,
                            mustBeGiven: lowered.mustBeGiven(default: parameter.default, in: table)
                        )
                    },
                    standing: { parameter in parameter.name }
                ),
                returns: signature?.returns?.lowered(in: table),
                purity: purity,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.lowered(in: table))

        case let .inout(inner):
            return .inout(inner.lowered(in: table))

        case let .nullable(inner):
            return .nullable(inner.lowered(in: table))

        // The mark does not survive lowering. What it says is proven at the
        // link and there is nothing left for a run to keep.
        case let .linear(inner):
            return inner.lowered(in: table)

        // Types and memberships are two spaces and no name is in both, so a
        // mention is looked for in each. A membership standing as a type is a
        // value of one of its members.
        case let .named(name):
            if let row = table.row(named: name) {
                return .named(row)
            }

            if let row = table.constraintRow(named: name) {
                return .member(row)
            }

            return .undeclared(label: name.spelling, refusal: "type '\(name)', which nothing declares")

        // A bound names a membership or a contract, and the two are separate
        // spaces, so it is looked for in each.
        case let .parameter(name, bound):
            guard let bound else { return .parameter(label: name, bound: nil) }

            if let row = table.constraintRow(named: bound) {
                return .parameter(label: name, bound: .membership(row))
            }

            if table.satisfying[bound] != nil {
                return .parameter(label: name, bound: .contract(bound))
            }

            return .undeclared(
                label: "some \(name): \(bound)",
                refusal: "'\(bound)', which nothing declares as a membership or a contract"
            )

        case let .reading(of, path):
            return .reading(of: of, path: path)
        }
    }
}

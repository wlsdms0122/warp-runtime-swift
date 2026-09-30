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

        case let .procedure(type, constness, isolation):
            return .procedure(
                parameters: type?.parameters.map { parameter in parameter.lowered(in: table) },
                returns: type?.returns?.lowered(in: table),
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.lowered(in: table))

        case let .inout(inner):
            return .inout(inner.lowered(in: table))

        case let .nullable(inner):
            return .nullable(inner.lowered(in: table))

        // No mark survives lowering: what one says is proven at the build, and
        // there is nothing left for a run to keep.
        case let .linear(inner), let .consuming(inner), let .borrowing(inner):
            return inner.lowered(in: table)

        // Types, memberships and contracts are three tables and no name is
        // in two, so a mention is looked for in each. A membership standing
        // as a type is a value of one of its members, and a contract standing
        // as a type is a value of whatever answers it.
        case let .named(name):
            if let row = table.row(named: name) {
                return .named(row)
            }

            guard let bound = table.bound(named: name) else {
                return .undeclared(label: name.spelling, because: .noTypeNamed(name))
            }

            return .composition([bound])

        // A bound names a membership or a contract, and the two are separate
        // spaces, so each is looked for in both.
        case let .parameter(name, constraints):
            return lowered(bounds: constraints, in: table) { bounds in .parameter(label: name, bounds: bounds) }

        case let .composition(names):
            return lowered(bounds: names, in: table, as: LoweredType.composition)

        case let .reading(of, path):
            return .reading(of: of, path: path)
        }
    }

    // What a list of names stands for: the bounds, in the one order a set of
    // bounds is written in, or the first name that is neither a membership
    // nor a contract.
    private func lowered(
        bounds names: [Name],
        in table: LoweredTypeTable,
        as bounded: ([LoweredType.Bound]) -> LoweredType
    ) -> LoweredType {
        var bounds: [LoweredType.Bound] = []

        for name in names {
            guard let bound = table.bound(named: name) else {
                return .undeclared(label: rendered, because: .noBoundNamed(name))
            }

            bounds.append(bound)
        }

        return bounded(bounds.sorted())
    }
}

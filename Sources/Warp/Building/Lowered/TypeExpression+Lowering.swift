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

        case let .procedure(signature, constness, isolation):
            return .procedure(
                parameters: signature?.ordered(
                    { name, parameter in
                        parameter.lowered(named: name, as: parameter.declared.lowered(in: table), in: table)
                    },
                    standing: { parameter in parameter.name }
                ),
                returns: signature?.returns?.lowered(in: table),
                constness: constness,
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
        // Neither mark survives lowering either, and for the same reason: what
        // they say is proven at the build.
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

            if let row = table.constraintRow(named: name) {
                return .composition([.membership(row)])
            }

            if table.satisfying[name] != nil {
                return .composition([.contract(name)])
            }

            return .undeclared(label: name.spelling, refusal: "type '\(name)', which nothing declares")

        // A bound names a membership or a contract, and the two are separate
        // spaces, so each is looked for in both.
        case let .parameter(name, constraints):
            if let unfound = unfound(constraints, in: table) {
                return .undeclared(label: rendered, refusal: "'\(unfound)', which nothing declares as a membership or a contract")
            }

            return .parameter(label: name, bounds: bounds(constraints, in: table))

        case let .composition(names):
            if let unfound = unfound(names, in: table) {
                return .undeclared(label: rendered, refusal: "'\(unfound)', which nothing declares as a membership or a contract")
            }

            return .composition(bounds(names, in: table))

        case let .reading(of, path):
            return .reading(of: of, path: path)
        }
    }

    // The first name among these that is neither a membership nor a contract.
    private func unfound(_ names: [Name], in table: LoweredTypeTable) -> Name? {
        names.first { name in table.constraintRow(named: name) == nil && table.satisfying[name] == nil }
    }

    // The bounds a list of declared names stands for, in the one order a
    // set of bounds is written in.
    private func bounds(_ names: [Name], in table: LoweredTypeTable) -> [LoweredType.Bound] {
        names.map { name in
            table.constraintRow(named: name).map(LoweredType.Bound.membership) ?? .contract(name)
        }
        .sorted()
    }
}

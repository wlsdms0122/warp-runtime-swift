//
//  TypeExpression+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension TypeExpression {
    // This type as the run reads it, with every name resolved to its row. A
    // name nothing declares lowers to the shape every judgment refuses, so
    // lowering is total and a table a host built by hand still answers for
    // every other name in it.
    //
    // A walk's reading lowers to `any`. A reading proves nothing about the
    // value it stands for, and every judgment answers it the way it answers
    // `any`; the reading exists apart from `any` for the walk's own naming.
    func lowered(in table: ShapeTable) -> Shape {
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

        case let .object(entry):
            return .object(entry.lowered(in: table))

        case let .record(fields):
            return .record(
                fields
                    .sorted { left, right in left.key < right.key }
                    .map { name, field in (name: name, shape: field.lowered(in: table)) }
            )

        case let .procedure(signature, purity, isolation):
            return .procedure(
                parameters: signature?.ordered.map { name, parameter in
                    (name: name, shape: parameter.declared.lowered(in: table))
                },
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

        case let .named(name):
            guard let row = table.row(named: name) else {
                return .undeclared(label: name, refusal: "type '\(name)', which nothing declares")
            }

            return .named(row)

        case let .parameter(name, constraint):
            guard let constraint else { return .parameter(label: name, constraint: nil) }

            guard let row = table.constraintRow(named: constraint) else {
                return .undeclared(
                    label: Name(normal: "some \(name): \(constraint)"),
                    refusal: "constraint '\(constraint)', which nothing declares"
                )
            }

            return .parameter(label: name, constraint: row)

        case .reading:
            return .any
        }
    }
}

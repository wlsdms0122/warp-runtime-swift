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
                    .sorted { left, right in Name.precedes(left.key, right.key) }
                    .map { name, field in (name: name, shape: field.lowered(in: table)) }
            )

        case let .procedure(signature, purity, isolation):
            return .procedure(
                parameters: signature?.ordered.map { name, parameter in
                    (name: name, shape: parameter.declared.lowered(in: table))
                },
                returns: signature?.returns?.lowered(in: table),
                purity,
                isolation
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
                    label: "some \(name): \(constraint)",
                    refusal: "constraint '\(constraint)', which nothing declares"
                )
            }

            return .parameter(label: name, constraint: row)

        case .reading:
            return .any
        }
    }
}

extension TypeTable {
    // The table as the run reads it. Rows are numbered by the order of the
    // declared spellings, so what a link concludes does not depend on the
    // order a caller listed its modules in. A name that names itself
    // through a chain of names stands for no shape and lowers to the shape
    // every judgment refuses, so a chain of names is always finite.
    func lowered() -> ShapeTable {
        let labels = types.keys.sorted(by: Name.precedes)
        let constraintLabels = constraints.keys.sorted(by: Name.precedes)

        // The index first, so a declaration naming another lowers against
        // rows that already exist whichever is declared first.
        let index = ShapeTable(
            shapes: [],
            constraints: [],
            labels: labels,
            constraintLabels: constraintLabels,
            recordRows: []
        )

        var shapes = labels.map { label in (types[label] ?? .any).lowered(in: index) }
        let members = constraintLabels.map { label in
            (constraints[label] ?? []).map { member in member.lowered(in: index) }
        }

        // The end of each row's chain of names, or nil where the chain comes
        // back on itself.
        func end(of start: Int) -> Int? {
            var row = start
            var walked: [Int] = [start]

            while case let .named(next) = shapes[row] {
                guard !walked.contains(next) else { return nil }

                walked.append(next)
                row = next
            }

            return row
        }

        for row in shapes.indices where end(of: row) == nil {
            shapes[row] = .undeclared(label: labels[row], refusal: "type '\(labels[row])', which names itself")
        }

        // The record a row names: the last row on the way to a record shape.
        let recordRows = shapes.indices.map { start -> Int? in
            guard let row = end(of: start), case .record = shapes[row] else { return nil }

            return row
        }

        return ShapeTable(
            shapes: shapes,
            constraints: members,
            labels: labels,
            constraintLabels: constraintLabels,
            recordRows: recordRows
        )
    }
}

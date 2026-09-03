//
//  TypeExpression+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension TypeExpression {
    // This type as the run reads it, with every name resolved to its row.
    // A name nothing declares is refused here, which is where a document's
    // type meets the table: the link has checked every name before it lowers
    // anything, so the refusal is met only at a host's door.
    //
    // A walk's reading lowers to `any`. A reading proves nothing about the
    // value it stands for, and every judgment answers it the way it answers
    // `any`; the reading exists apart from `any` for the walk's own naming.
    func lowered(in table: ShapeTable) throws -> Shape {
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
            return .array(try element.lowered(in: table))

        case let .object(entry):
            return .object(try entry.lowered(in: table))

        case let .record(fields):
            return .record(
                try fields
                    .sorted { left, right in Name.precedes(left.key, right.key) }
                    .map { name, field in (name: name, shape: try field.lowered(in: table)) }
            )

        case let .procedure(signature, purity, isolation):
            return .procedure(
                parameters: try signature?.ordered.map { name, parameter in
                    (name: name, shape: try parameter.declared.lowered(in: table))
                },
                returns: try signature?.returns?.lowered(in: table),
                purity,
                isolation
            )

        case let .variable(inner):
            return .variable(try inner.lowered(in: table))

        case let .inout(inner):
            return .inout(try inner.lowered(in: table))

        case let .nullable(inner):
            return .nullable(try inner.lowered(in: table))

        case let .named(name):
            guard let row = table.row(named: name) else {
                throw UndeclaredTypeError("declares type '\(name)', which nothing declares")
            }

            return .named(row)

        case let .parameter(name, constraint):
            guard let constraint else { return .parameter(label: name, constraint: nil) }

            guard let row = table.constraintRow(named: constraint) else {
                throw UndeclaredTypeError("declares constraint '\(constraint)', which nothing declares")
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
    // order a caller listed its modules in.
    func lowered() throws -> ShapeTable {
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

        let shapes = try labels.map { label in try (types[label] ?? .any).lowered(in: index) }
        let members = try constraintLabels.map { label in
            try (constraints[label] ?? []).map { member in try member.lowered(in: index) }
        }

        // The record a row names: the last row on the way to a record shape.
        // A chain that comes back to itself names no record, which the link
        // refuses before lowering and a table built by hand answers as none.
        let recordRows = shapes.indices.map { start -> Int? in
            var row = start
            var walked: [Int] = []

            while case let .named(next) = shapes[row] {
                guard !walked.contains(next) else { return nil }

                walked.append(next)
                row = next
            }

            if case .record = shapes[row] { return row }

            return nil
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

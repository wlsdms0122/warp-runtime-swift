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

        // Types and contracts are two tables and no name is in both, so a
        // mention is looked for in each. A contract standing as a type is a
        // value of whatever answers it.
        case let .named(name):
            if let row = table.row(named: name) {
                return .named(row)
            }

            guard table.declaresContract(name) else {
                return .undeclared(label: name.spelling, because: .noTypeNamed(name))
            }

            return .composition([name])

        // A bound names a contract.
        case let .parameter(name, names):
            return lowered(bounds: names, in: table) { bounds in .parameter(label: name, bounds: bounds) }

        case let .composition(names):
            return lowered(bounds: names, in: table, as: LoweredType.composition)

        case let .projection(of, path):
            return .projection(of: of, path: path)

        // A contract's procedures read `Self` before anything lowers them, so
        // what is left is `Self` written where no contract stands, which is
        // refused where it was written.
        case .selfType:
            return .undeclared(label: TypeSpelling.selfType.spelling, because: .noTypeNamed(TypeSpelling.selfType))
        }
    }

    // What a list of names stands for: the contracts, in the one order a set
    // of bounds is written in, or the first name that is no contract.
    private func lowered(
        bounds names: [Name],
        in table: LoweredTypeTable,
        as bounded: ([Name]) -> LoweredType
    ) -> LoweredType {
        if let name = names.first(where: { name in !table.declaresContract(name) }) {
            return .undeclared(label: rendered, because: .noBoundNamed(name))
        }

        return bounded(names.sorted())
    }
}

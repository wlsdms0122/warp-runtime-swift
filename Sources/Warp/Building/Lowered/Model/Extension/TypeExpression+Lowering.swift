//
//  TypeExpression+Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension TypeExpression {
    // This type as the run reads it, with every declared name resolved: a
    // record to its row, and an alias to what it stands for. A name nothing
    // declares, a bound naming no contract and `Self` outside a contract
    // stand for no type, so each lowers to `Never`. A build refuses the first
    // two in every document and object before it reads a lowering, and a
    // table a host builds is held to the same judge; the load refuses the
    // third in a document, and an object writing it there reads it as
    // `Never`. `bounds` are what the signature this type is written in holds
    // each type parameter to, by its name.
    func lowered(in table: LoweredTypeTable, bounds: [Name: Set<Name>] = [:]) -> LoweredType {
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
            return .array(element.lowered(in: table, bounds: bounds))

        case let .dictionary(entry):
            return .dictionary(entry.lowered(in: table, bounds: bounds))

        case let .record(fields):
            let ordered = fields.sorted { left, right in left.key < right.key }

            return .record(
                LoweredRecord(
                    layout: Layout(name: nil, ordered: ordered.map(\.key)),
                    fields: ordered.map { _, field in field.lowered(in: table, bounds: bounds) }
                )
            )

        case let .procedure(type, constness, isolation):
            return .procedure(
                type.map { type in
                    LoweredProcedureType(
                        parameters: type.parameters.map { parameter in parameter.lowered(in: table, bounds: bounds) },
                        returns: type.returns?.lowered(in: table, bounds: bounds)
                    )
                },
                constness: constness,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.lowered(in: table, bounds: bounds))

        case let .inout(inner):
            return .inout(inner.lowered(in: table, bounds: bounds))

        case let .nullable(inner):
            return inner.lowered(in: table, bounds: bounds).admittingNull

        // Types and contracts are two tables and no name is in both, so a
        // mention is looked for in each. A contract standing as a type is a
        // value of whatever answers it.
        case let .named(name):
            if let row = table.row(named: name) {
                return table.mention(of: row)
            }

            guard table.declaresContract(name) else { return .never }

            return .composition([name])

        // A bound names a contract.
        case let .parameter(name):
            return lowered(bounds: bounds[name] ?? [], in: table) { bounds in .parameter(label: name, bounds: bounds) }

        case let .composition(names):
            return lowered(bounds: names, in: table, as: LoweredType.composition)

        case let .projection(of, path):
            return .projection(of: of, path: path)

        // A contract's procedures read `Self` before anything lowers them, so
        // what is left is `Self` written where no contract stands, which is
        // refused where it was written.
        case .selfType:
            return .never
        }
    }

    // What a set of names stands for: the contracts, in the one order a set
    // of bounds is written in, or `Never` where a name is no contract.
    private func lowered(
        bounds names: some Collection<Name>,
        in table: LoweredTypeTable,
        as bounded: ([Name]) -> LoweredType
    ) -> LoweredType {
        guard names.allSatisfy(table.declaresContract) else { return .never }

        return bounded(names.sorted())
    }
}

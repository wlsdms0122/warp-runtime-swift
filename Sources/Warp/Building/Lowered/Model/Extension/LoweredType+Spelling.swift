//
//  LoweredType+Spelling.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

extension LoweredType {
    // This type as a declaration writes it: lowering run backwards. A
    // declared name goes back to its label, so what it stands for, a mark
    // lowering dropped included, is read again where the spelling is
    // lowered. A whole literal is read as the Int a name holds it as. A type
    // parameter goes back to its name, its bounds being the signature's.
    func spelled(in table: LoweredTypeTable) -> TypeExpression {
        switch self {
        case .any:
            return .any

        case .never:
            return .never

        case .null:
            return .null

        case .bool:
            return .bool

        case .int, .wholeLiteral:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case let .array(element):
            return .array(element.spelled(in: table))

        case let .dictionary(entry):
            return .dictionary(entry.spelled(in: table))

        case let .record(record):
            return .record(Dictionary(uniqueKeysWithValues: record.named.map { name, field in (name, field.spelled(in: table)) }))

        case let .procedure(parameters, returns, constness, isolation):
            guard let parameters else { return .procedure(nil, constness, isolation) }

            return .procedure(
                ProcedureType(
                    parameters: parameters.map { parameter in parameter.spelled(in: table) },
                    returns: returns?.spelled(in: table)
                ),
                constness,
                isolation
            )

        case let .variable(inner):
            return .variable(inner.spelled(in: table))

        case let .inout(inner):
            return .inout(inner.spelled(in: table))

        case let .nullable(inner):
            return .nullable(inner.spelled(in: table))

        case let .named(row):
            return .named(table.labels[row])

        case let .parameter(label, _):
            return .parameter(name: label)

        case let .composition(names):
            return .composition(names)

        case let .projection(of, path):
            return .projection(of: of, path: path)
        }
    }
}

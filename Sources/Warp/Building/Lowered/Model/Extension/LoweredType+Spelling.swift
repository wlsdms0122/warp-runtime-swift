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
    // lowered. A whole literal is read as the Int a name holds it as. Nil
    // for a name the table does not answer, which no declaration spells.
    func spelled(in table: LoweredTypeTable) -> TypeExpression? {
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

        case let .ranged(refinement):
            return .ranged(refinement)

        case let .array(element):
            return element.spelled(in: table).map(TypeExpression.array)

        case let .dictionary(entry):
            return entry.spelled(in: table).map(TypeExpression.dictionary)

        case let .record(record):
            var fields: [Name: TypeExpression] = [:]

            for (name, field) in record.named {
                guard let spelled = field.spelled(in: table) else { return nil }

                fields[name] = spelled
            }

            return .record(fields)

        case let .procedure(parameters, returns, constness, isolation):
            guard let parameters else { return .procedure(nil, constness, isolation) }

            let taken = parameters.compactMap { parameter in parameter.spelled(in: table) }
            let answer = returns.map { returns in returns.spelled(in: table) }

            guard taken.count == parameters.count, answer != .some(nil) else { return nil }

            return .procedure(ProcedureType(parameters: taken, returns: answer ?? nil), constness, isolation)

        case let .variable(inner):
            return inner.spelled(in: table).map(TypeExpression.variable)

        case let .inout(inner):
            return inner.spelled(in: table).map(TypeExpression.inout)

        case let .nullable(inner):
            return inner.spelled(in: table).map(TypeExpression.nullable)

        case let .named(row):
            return .named(table.labels[row])

        case let .parameter(label, bounds):
            return .parameter(name: label, bounds: bounds)

        case let .composition(names):
            return .composition(names)

        case let .projection(of, path):
            return .projection(of: of, path: path)

        case .undeclared:
            return nil
        }
    }
}

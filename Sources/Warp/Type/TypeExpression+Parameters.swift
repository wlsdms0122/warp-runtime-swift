//
//  TypeExpression+Parameters.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// The type parameters a type mentions: each occurrence with the bound it
// carries, whether there is one at all, and the type with every occurrence
// carrying the bound its signature declared.
extension TypeExpression {
    // Every type parameter mentioned in here, occurrence by occurrence.
    var parameterOccurrences: [ParameterOccurrence] {
        switch self {
        case let .parameter(name, constraints):
            return [ParameterOccurrence(name: name, constraints: constraints)]

        case .reading, .composition:
            return []

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            return element.parameterOccurrences

        case let .record(fields):
            return fields.values.flatMap { field in field.parameterOccurrences }

        case let .procedure(type, _, _):
            return type?.parameterOccurrences ?? []

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return inner.parameterOccurrences

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named:
            return []
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read the way it always was, so nothing pays for a feature it does not
    // use.
    var isGeneric: Bool {
        switch self {
        // Both are types a call decides, and the deep question is only
        // whether this declaration has to be filled at all.
        case .parameter, .reading:
            return true

        case let .array(element), let .dictionary(element), let .nullable(element), let .linear(element):
            return element.isGeneric

        case let .record(fields):
            return fields.values.contains { field in field.isGeneric }

        case let .procedure(type, _, _):
            return type?.isGeneric ?? false

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return inner.isGeneric

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named, .composition:
            return false
        }
    }

    // The occurrence side of `Signature.bounded(by:)`, walked through every
    // place a type parameter may sit. A nested procedure type's parameters
    // included, because they are the outer signature's own slots.
    func bounded(by bounds: [Name: [Name]]) -> TypeExpression {
        switch self {
        case let .parameter(name, constraints):
            return .parameter(name: name, constraints: constraints.isEmpty ? bounds[name] ?? [] : constraints)

        case .reading, .composition:
            return self

        case let .linear(inner):
            return .linear(inner.bounded(by: bounds))

        case let .array(element):
            return .array(element.bounded(by: bounds))

        case let .dictionary(entry):
            return .dictionary(entry.bounded(by: bounds))

        case let .record(fields):
            return .record(fields.mapValues { field in field.bounded(by: bounds) })

        case let .procedure(type, constness, isolation):
            return .procedure(type?.bounded(by: bounds), constness, isolation)

        case let .nullable(inner):
            return .nullable(inner.bounded(by: bounds))

        case let .variable(inner):
            return .variable(inner.bounded(by: bounds))

        case let .inout(inner):
            return .inout(inner.bounded(by: bounds))

        case let .consuming(inner):
            return .consuming(inner.bounded(by: bounds))

        case let .borrowing(inner):
            return .borrowing(inner.bounded(by: bounds))

        case .any, .never, .null, .bool, .int, .double, .string, .ranged, .named:
            return self
        }
    }
}

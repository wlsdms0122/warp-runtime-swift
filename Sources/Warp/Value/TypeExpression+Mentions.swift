//
//  TypeExpression+Mentions.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

extension TypeExpression {
    // MARK: - Internal
    // Every declared name this reaches: the types it names, and the
    // memberships it bounds a parameter by.
    //
    // A parameter's own name is not one of them. It stands for a shape the
    // call decides rather than one a module declared, and what a walk through
    // one reached is rooted at that same undeclared shape.
    var mentions: Set<Name> {
        switch self {
        case .any, .never, .null, .bool, .int, .double, .string, .bytes, .number, .ranged:
            []

        case let .array(element):
            element.mentions

        case let .dictionary(entry):
            entry.mentions

        case let .record(fields):
            fields.values.reduce(into: Set()) { mentioned, field in
                mentioned.formUnion(field.mentions)
            }

        case let .procedure(signature, _, _):
            signature?.mentions ?? []

        case let .variable(inner), let .inout(inner), let .once(inner), let .nullable(inner):
            inner.mentions

        case let .named(name):
            [name]

        case let .parameter(_, constraint):
            constraint.map { name in [name] } ?? []

        case .reading:
            []
        }
    }
}

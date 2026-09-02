//
//  Statement.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A binding and an expression. That is the only statement the language has,
// because everything else is an expression — `when` is a conditional, `rescue`
// is an attempt, and both are things you bind rather than modifiers you attach
// to an envelope.
//
// What the binding *does* to its name is the second thing a statement says: a
// name is fixed, or it is a variable, or this is a write into a variable
// declared earlier. A statement with no binding runs for its effect and drops
// the answer.
public struct Statement: Sendable {
    // The name is inside the case, so a variable without a name is not a value
    // this type can hold. A write names a path rather than a name: `set` reaches
    // into a variable through its fields and elements, and the head of the path
    // is the variable it writes.
    public enum Binding: Sendable, Equatable {
        case constant(String)
        case variable(String)
        case assignment([PathSegment])

        // The name a statement introduces, where it introduces one. A write
        // introduces nothing.
        public var introduced: String? {
            switch self {
            case let .constant(name), let .variable(name):
                return name

            case .assignment:
                return nil
            }
        }

        // What the statement is called by: the name it binds, or the head of
        // the path it writes.
        public var name: String? {
            switch self {
            case let .constant(name), let .variable(name):
                return name

            case let .assignment(path):
                return path.head
            }
        }

        // The text a document writes under the naming key: the name, or the
        // path as one string.
        public var spelled: String {
            switch self {
            case let .constant(name), let .variable(name):
                return name

            case let .assignment(path):
                return path.rendered
            }
        }

        public var isConstant: Bool {
            if case .constant = self { return true }
            return false
        }

        public var isAssignment: Bool {
            if case .assignment = self { return true }
            return false
        }
    }

    // MARK: - Property
    public let binding: Binding?
    public let expression: Expression

    // MARK: - Initializer
    public init(binding: Binding? = nil, expression: Expression) {
        self.binding = binding
        self.expression = expression
    }

    // MARK: - Public
    // The name a statement is called by, for a place that points at it.
    public var name: String? { binding?.name }

    // MARK: - Private
}

extension [Statement] {
    // Whether every way through this sequence leaves. A sequence leaves when
    // one of its statements always leaves, because nothing after that one runs.
    public var alwaysLeaves: Bool {
        contains { statement in statement.expression.alwaysLeaves }
    }
}

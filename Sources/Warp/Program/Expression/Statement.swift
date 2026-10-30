//
//  Statement.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A binding and an expression. That is the only statement the language has,
// because everything else is an expression.
//
// What the binding *does* to its name is the second thing a statement says: a
// name is fixed, or it is a variable, or this is a write into a variable
// declared earlier. A statement with no binding runs for its effect and drops
// its value.
public struct Statement: Sendable {
    // The name is inside the case, so a variable without a name is not a value
    // this type can hold. A write names a path rather than a name: `set` reaches
    // into a variable through its fields, elements and entries, and the head of
    // the path is the variable it writes.
    //
    // A name may say what it holds. The declaration is on the two cases that
    // introduce a name, so a write cannot carry one: `set` reaches a name
    // something else declared.
    public enum Binding: Sendable, Equatable {
        case constant(Name, declared: TypeExpression? = nil)
        case variable(Name, declared: TypeExpression? = nil)
        case assignment(Path)

        // MARK: - Property
        // The name a statement introduces, where it introduces one. A write
        // introduces nothing.
        public var introduced: Name? {
            switch self {
            case let .constant(name, _), let .variable(name, _):
                return name

            case .assignment:
                return nil
            }
        }

        // What the name says it holds, where it says. Nil is not `Any`: a name
        // that declares nothing holds what the build worked out for it, and one
        // that declares `Any` holds `Any`.
        public var declared: TypeExpression? {
            switch self {
            case let .constant(_, declared), let .variable(_, declared):
                return declared

            case .assignment:
                return nil
            }
        }

        // What the statement is called by: the name it binds, or the head of
        // the path it writes.
        public var name: Name? {
            switch self {
            case let .constant(name, _), let .variable(name, _):
                return name

            case let .assignment(path):
                return path.head
            }
        }

        var isConstant: Bool {
            if case .constant = self { return true }
            return false
        }

        var isAssignment: Bool {
            if case .assignment = self { return true }
            return false
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    public let binding: Binding?
    public let expression: Expression

    // The name a statement is called by, for a place that points at it.
    public var name: Name? { binding?.name }

    // What this statement binds for the statements after it. A construct
    // with no value binds nothing there.
    var bindingAfter: Binding? {
        expression.hasNoValue ? nil : binding
    }

    // The name this statement's construct binds inside itself: a loop's
    // round, read in its condition and its body, a try's failure, read
    // in its catch alone, and an unwrap's payload, read in its `then`
    // alone. A construct that names its own and has a value, an unwrap with
    // no `then`, binds it after itself. Every other construct binds nothing
    // inside, and neither does a statement that introduces no name.
    var nameInside: Name? {
        expression.namesItsOwn && expression.hasNoValue ? binding?.introduced : nil
    }

    // MARK: - Initializer
    public init(binding: Binding? = nil, expression: Expression) {
        self.binding = binding
        self.expression = expression
    }

    // MARK: - Public
    // The steps from a body's place to what this statement writes: the
    // statement, by its name or, nameless, its position, and then the
    // construct it writes. The statement itself stands one step short of
    // what it writes. Every walk takes them from here.
    public func steps(at position: Int) -> [Place.Step] {
        [Place.Step.statement(name?.spelling, at: position), .construct(expression.construct)]
    }

    // MARK: - Private
}

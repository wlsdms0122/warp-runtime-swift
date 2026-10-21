//
//  TypeSyntax.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// A type as its spelling writes it, before anything it says is judged: the
// parts in the order they are written, a name as the text it is written as,
// and a part written twice kept twice. What the type is, is a
// `TypeExpression`; this is how it is written, so a spelling is cut into one
// of these once and written out of one once.
//
//   Int  App.Point  Self.Item           a name
//   Array<T>  App.Box<Int, String>      a name applied to the types its
//                                       brackets hold
//   T?  (() -> Int)?                    null or the type, in parentheses where
//                                       the type is a procedure type or
//                                       modified
//   A & B                               names joined
//   some T  some T: A & B               a type parameter, and its bound
//   inout T  var T                      a slot's mark in front of a type
//   const isolated T                    modifiers in front of a type
//   (A, B) throws(x) -> R               a procedure type
package indirect enum TypeSyntax: Sendable, Equatable {
    // What a slot writes in front of a whole type: `var` a field's, `inout`
    // a parameter's.
    package enum Mark: CaseIterable, Sendable {
        case variable
        case `inout`

        // MARK: - Property
        package var word: Name {
            switch self {
            case .variable: TypeSpelling.variable
            case .inout: TypeSpelling.inout
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // What a slot asks of the whole procedure type after it.
    package enum Modifier: CaseIterable, Sendable {
        case const
        case isolated

        // MARK: - Property
        package var word: Name {
            switch self {
            case .const: TypeSpelling.const
            case .isolated: TypeSpelling.isolated
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // What a procedure type writes between its parameters and its arrow:
    // `throws` alone, or `throws(…)` and the names it lists.
    package enum Throwing: Sendable, Equatable {
        case anything
        case these([String])
    }

    case name(String)
    case applied(String, [TypeSyntax])
    case nullable(TypeSyntax)
    case composition([String])
    case parameter(String, bound: [String]?)
    case marked(Mark, TypeSyntax)
    case modified([Modifier], TypeSyntax)
    case procedure([TypeSyntax], throwing: Throwing?, returns: TypeSyntax)

    // MARK: - Property
    // The text this is. A part holding others is spelled in a function of
    // its own, so a level of the walk holds the dispatch and that one form.
    package var spelling: String {
        switch self {
        case let .name(name):
            return name

        case let .applied(name, arguments):
            return Self.spelled(name, holding: arguments)

        case let .nullable(inner):
            return Self.spelled(nullable: inner)

        case let .composition(names):
            return names.joined(separator: " & ")

        case let .parameter(name, bound):
            return Self.spelled(parameter: name, bound)

        case let .marked(mark, inner):
            return Self.spelled(mark, before: inner)

        case let .modified(modifiers, inner):
            return Self.spelled(modifiers, before: inner)

        case let .procedure(parameters, throwing, returns):
            return Self.spelled(parameters, throwing, returns)
        }
    }

    // MARK: - Initializer
    // The syntax a document writes a type in. `bound` answers the contracts a
    // type parameter is written beside at a naming, asked of each naming in
    // the order the spelling writes them, and nil where it is written bare.
    // Contracts, failures and a composition's names are written in one
    // order, since the type holds them as a set.
    package init(_ type: TypeExpression, bounding bound: (Name) -> Set<Name>?) {
        switch type {
        case .any:
            self = .name(TypeSpelling.any.spelling)

        case .never:
            self = .name(TypeSpelling.never.spelling)

        case .null:
            self = .name(TypeSpelling.null.spelling)

        case .bool:
            self = .name(TypeSpelling.bool.spelling)

        case .int:
            self = .name(TypeSpelling.int.spelling)

        case .double:
            self = .name(TypeSpelling.double.spelling)

        case .string:
            self = .name(TypeSpelling.string.spelling)

        case .selfType:
            self = .name(TypeSpelling.selfType.spelling)

        case let .parameter(name):
            self = .parameter(name.spelling, bound: bound(name).map(Self.sorted))

        case let .composition(names):
            self = .composition(Self.sorted(names))

        case let .associatedType(of, name):
            self = Self.associated(name, of: of)

        case let .variable(inner):
            self = Self.marked(.variable, inner, bounding: bound)

        case let .inout(inner):
            self = Self.marked(.inout, inner, bounding: bound)

        case let .procedure(type, constness, isolation):
            self = Self.procedure(type, constness, isolation, bounding: bound)

        case let .array(element):
            self = Self.applied(TypeSpelling.array, [element], bounding: bound)

        case let .dictionary(key, value):
            self = Self.applied(TypeSpelling.dictionary, [key, value], bounding: bound)

        case let .named(name, arguments):
            self = arguments.isEmpty ? .name(name.spelling) : Self.applied(name, arguments, bounding: bound)

        case let .nullable(inner):
            self = .nullable(TypeSyntax(inner, bounding: bound))
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func sorted(_ names: Set<Name>) -> [String] {
        names.sorted().map(\.spelling)
    }

    private static func associated(_ name: Name, of owner: Name) -> TypeSyntax {
        let spelled = name.spelled(under: owner).spelling

        guard owner.root != TypeSpelling.selfType else { return .name(spelled) }

        return .parameter(spelled, bound: nil)
    }

    private static func marked(_ mark: Mark, _ inner: TypeExpression, bounding bound: (Name) -> Set<Name>?) -> TypeSyntax {
        .marked(mark, TypeSyntax(inner, bounding: bound))
    }

    private static func applied(
        _ name: Name,
        _ arguments: [TypeExpression],
        bounding bound: (Name) -> Set<Name>?
    ) -> TypeSyntax {
        var applied: [TypeSyntax] = []

        for argument in arguments {
            applied.append(TypeSyntax(argument, bounding: bound))
        }

        return .applied(name.spelling, applied)
    }

    private static func procedure(
        _ type: ProcedureType?,
        _ constness: Constness,
        _ isolation: Isolation,
        bounding bound: (Name) -> Set<Name>?
    ) -> TypeSyntax {
        let modifiers = [constness == .const ? Modifier.const : nil, isolation == .isolated ? .isolated : nil]
            .compactMap { modifier in modifier }
        let written = type.map { type in signature(type, bounding: bound) } ?? .name(TypeSpelling.procedure.spelling)

        return modifiers.isEmpty ? written : .modified(modifiers, written)
    }

    private static func signature(_ type: ProcedureType, bounding bound: (Name) -> Set<Name>?) -> TypeSyntax {
        var parameters: [TypeSyntax] = []

        for parameter in type.parameters {
            parameters.append(TypeSyntax(parameter, bounding: bound))
        }

        let throwing: Throwing? = switch type.failing {
        case .anything: .anything
        case let .these(failures) where failures.isEmpty: nil
        case let .these(failures): .these(failures.sorted())
        }

        return .procedure(parameters, throwing: throwing, returns: TypeSyntax(type.returns, bounding: bound))
    }

    private static func spelled(_ name: String, holding arguments: [TypeSyntax]) -> String {
        var spelled: [String] = []

        for argument in arguments {
            spelled.append(argument.spelling)
        }

        return "\(name)<\(spelled.joined(separator: ", "))>"
    }

    // Everything after `->` is a procedure's answer, and a modifier stands in
    // front of the whole type after it, so a `?` meaning either one whole is
    // written after parentheses around it.
    private static func spelled(nullable inner: TypeSyntax) -> String {
        switch inner {
        case .procedure, .modified:
            return "(\(inner.spelling))?"

        case .name, .applied, .nullable, .composition, .parameter, .marked:
            return "\(inner.spelling)?"
        }
    }

    private static func spelled(parameter name: String, _ bound: [String]?) -> String {
        guard let bound else { return "\(TypeSpelling.some) \(name)" }

        return "\(TypeSpelling.some) \(name): \(bound.joined(separator: " & "))"
    }

    private static func spelled(_ mark: Mark, before inner: TypeSyntax) -> String {
        "\(mark.word) \(inner.spelling)"
    }

    private static func spelled(_ modifiers: [Modifier], before inner: TypeSyntax) -> String {
        modifiers.map { modifier in "\(modifier.word) " }.joined() + inner.spelling
    }

    private static func spelled(_ parameters: [TypeSyntax], _ throwing: Throwing?, _ returns: TypeSyntax) -> String {
        var spelled: [String] = []

        for parameter in parameters {
            spelled.append(parameter.spelling)
        }

        let thrown = switch throwing {
        case nil: ""
        case .anything: " \(TypeSpelling.throws)"
        case let .these(failures): " \(TypeSpelling.throws)(\(failures.joined(separator: ", ")))"
        }

        return "(\(spelled.joined(separator: ", ")))\(thrown) -> \(returns.spelling)"
    }
}

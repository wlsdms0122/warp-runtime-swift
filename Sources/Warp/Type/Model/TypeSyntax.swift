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
//   Int  App.Point                      a name
//   Array<T>  App.Box<Int, String>      a name applied to the types its
//                                       brackets hold
//   T?  (() -> Int)?  (some T: A)?      the Optional of the type, in parentheses where
//                                       the type is a procedure type,
//                                       modified or a bounded parameter
//   A & B                               names joined
//   some T  some T: A & B               a type parameter, and its bound
//   some T.Item.Key  Self.Item          an associated type
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

    // Contracts joined by `&`, in the order written: a bound, and the names
    // a composition joins.
    package struct Bound: Sendable, Equatable {
        // MARK: - Property
        package let contracts: [String]

        package var spelling: String {
            contracts.joined(separator: " & ")
        }

        // MARK: - Initializer
        package init(_ contracts: [String]) {
            self.contracts = contracts
        }

        // A set of contracts, written in one order.
        package init(_ contracts: Set<Name>) {
            self.contracts = contracts.sorted().map(\.spelling)
        }

        // MARK: - Public
        // MARK: - Private
    }

    // A name where it is introduced, and the bound written beside it:
    // `K: A & B`, or the name alone.
    package struct Introduced: Sendable, Equatable {
        // MARK: - Property
        package let name: String
        package let bound: Bound?

        package var spelling: String {
            guard let bound else { return name }

            return "\(name): \(bound.spelling)"
        }

        // MARK: - Initializer
        package init(_ name: String, bound: Bound?) {
            self.name = name
            self.bound = bound
        }

        // MARK: - Public
        // MARK: - Private
    }

    // An associated type: the type parameter it stands on, after `some`,
    // or `Self`, then each member's name after a dot, as written.
    package struct Associated: Sendable, Equatable {
        package enum Base: Sendable, Equatable {
            case parameter(String)
            case selfType

            // MARK: - Property
            package var name: String {
                switch self {
                case let .parameter(name): name
                case .selfType: TypeSpelling.selfType.spelling
                }
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        package let base: Base
        package let members: [String]

        // The base and the members with a dot between each.
        package var label: String {
            ([base.name] + members).joined(separator: ".")
        }

        package var spelling: String {
            switch base {
            case .parameter: "\(TypeSpelling.some) \(label)"
            case .selfType: label
            }
        }

        // MARK: - Initializer
        package init(_ base: Base, members: [String]) {
            self.base = base
            self.members = members
        }

        // MARK: - Public
        // MARK: - Private
    }

    case name(String)
    case applied(String, [TypeSyntax])
    case optional(TypeSyntax)
    case composition(Bound)
    case parameter(Introduced)
    case associated(Associated)
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

        case let .optional(inner):
            return Self.spelled(optional: inner)

        case let .composition(names):
            return names.spelling

        case let .parameter(introduced):
            return "\(TypeSpelling.some) \(introduced.spelling)"

        case let .associated(associated):
            return associated.spelling

        case let .marked(mark, inner):
            return Self.spelled(mark, before: inner)

        case let .modified(modifiers, inner):
            return Self.spelled(modifiers, before: inner)

        case let .procedure(parameters, throwing, returns):
            return Self.spelled(parameters, throwing, returns)
        }
    }

    // MARK: - Initializer
    // The syntax a document writes a type in. Each type parameter `bounds`
    // holds is written beside its first naming, in the order the spelling
    // writes them. Contracts, failures and a composition's names are written
    // in one order, since the type holds them as a set.
    package init(_ type: TypeExpression, bounds: [Name: Set<Name>] = [:]) {
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
            self = .parameter(Introduced(name.spelling, bound: bounds[name].map(Bound.init)))

        case let .composition(names):
            self = .composition(Bound(names))

        case let .associatedType(associated):
            self = .associated(
                Associated(
                    associated.base == TypeSpelling.selfType ? .selfType : .parameter(associated.base.spelling),
                    members: associated.members.map(\.spelling)
                )
            )

        case let .variable(inner):
            self = .marked(.variable, TypeSyntax(inner, bounds: bounds))

        case let .inout(inner):
            self = .marked(.inout, TypeSyntax(inner, bounds: bounds))

        case let .procedure(type, constness, isolation):
            self = Self.procedure(type, constness, isolation, bounds: bounds)

        case let .array(element):
            self = .applied(TypeSpelling.array.spelling, Self.parts([element], bounds: bounds))

        case let .dictionary(key, value):
            self = .applied(TypeSpelling.dictionary.spelling, Self.parts([key, value], bounds: bounds))

        case let .named(name, arguments) where arguments.isEmpty:
            self = .name(name.spelling)

        case let .named(name, arguments):
            self = .applied(name.spelling, Self.parts(arguments, bounds: bounds))

        case let .optional(inner):
            self = .optional(TypeSyntax(inner, bounds: bounds))
        }
    }

    // MARK: - Public
    // Types written one after another, as a procedure type's parameters and
    // return type or a struct's arguments: a bound is written beside a type
    // parameter's first naming across them all.
    package static func parts(_ types: [TypeExpression], bounds: [Name: Set<Name>]) -> [TypeSyntax] {
        var unwritten = bounds
        var parts: [TypeSyntax] = []

        for type in types {
            parts.append(TypeSyntax(type, bounds: unwritten))
            unwritten = unwritten.filter { name, _ in !type.parameterNames.contains(name) }
        }

        return parts
    }

    // MARK: - Private
    private static func procedure(
        _ type: ProcedureType?,
        _ constness: Constness,
        _ isolation: Isolation,
        bounds: [Name: Set<Name>]
    ) -> TypeSyntax {
        let modifiers = [constness == .const ? Modifier.const : nil, isolation == .isolated ? .isolated : nil]
            .compactMap { modifier in modifier }
        let written = type.map { type in signature(type, bounds: bounds) }
            ?? .name(TypeSpelling.procedure.spelling)

        return modifiers.isEmpty ? written : .modified(modifiers, written)
    }

    private static func signature(_ type: ProcedureType, bounds: [Name: Set<Name>]) -> TypeSyntax {
        var parameters = parts(type.parameters + [type.returns], bounds: bounds)
        let returns = parameters.removeLast()
        let throwing: Throwing? = switch type.failing {
        case .anything: .anything
        case let .these(failures) where failures.isEmpty: nil
        case let .these(failures): .these(failures.sorted())
        }

        return .procedure(parameters, throwing: throwing, returns: returns)
    }

    private static func spelled(_ name: String, holding arguments: [TypeSyntax]) -> String {
        var spelled: [String] = []

        for argument in arguments {
            spelled.append(argument.spelling)
        }

        return "\(name)<\(spelled.joined(separator: ", "))>"
    }

    // Everything after `->` is a procedure's return type, a modifier stands
    // in front of the whole type after it, and a bound runs to the end of
    // the spelling, so a `?` meaning any of them whole is written after
    // parentheses around it.
    private static func spelled(optional inner: TypeSyntax) -> String {
        switch inner {
        case .procedure, .modified:
            return "(\(inner.spelling))?"

        case let .parameter(introduced) where introduced.bound != nil:
            return "(\(inner.spelling))?"

        case .name, .applied, .optional, .composition, .parameter, .associated, .marked:
            return "\(inner.spelling)?"
        }
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

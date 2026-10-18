//
//  Head.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// What a document gives a type is given to: the type, and what it is applied
// to where what is given holds only for some of its values. Each `some T` an
// argument writes is the head's own type parameter, held to the contracts
// beside it, so `App.Box<some T: Hashable>` is every box of something that
// answers `Hashable`, and `Array<Int>` every list of integers.
//
// A head applied to nothing is bare and is about every value of the type,
// which is what a struct's declaration gives.
public struct Head: Sendable, Hashable, Comparable, ExpressibleByStringLiteral {
    // MARK: - Property
    public let type: Name
    public let arguments: [TypeExpression]
    public let bounds: [Name: Set<Name>]

    public var isBare: Bool { arguments.isEmpty }

    // The one spelling: the type, and what it is applied to between its
    // brackets, each type parameter's bounds written where it is first named.
    public var spelling: Name {
        guard !arguments.isEmpty else { return type }

        var named: Set<Name> = []
        let written = arguments.map { argument in
            argument.spelled { name in named.insert(name).inserted ? bounds[name] : nil }
        }

        return Name(normal: "\(type.spelling)<\(written.joined(separator: ", "))>")
    }

    // The type a value of this head is an instance of, applied as the head
    // applies it. Nil where the head is bare: a bare head is the type itself,
    // whatever it is applied to.
    var mention: TypeExpression? {
        guard !arguments.isEmpty else { return nil }

        switch (type, arguments.count) {
        case (TypeSpelling.array, 1):
            return .array(arguments[0])

        case (TypeSpelling.dictionary, 2):
            return .dictionary(key: arguments[0], value: arguments[1])

        default:
            return .named(type, arguments: arguments)
        }
    }

    // Every declared name this reaches: the type, what it is applied to, and
    // the contracts its bounds name.
    var mentions: Set<Name> {
        arguments.reduce(into: Set([type]).union(bounds.values.joined())) { mentioned, argument in
            mentioned.formUnion(argument.mentions)
        }
    }

    // The type parameters the head's arguments name.
    var parameterNames: Set<Name> {
        arguments.reduce(into: []) { names, argument in names.formUnion(argument.parameterNames) }
    }

    // What a claim under this head is about, as a contract's procedures read
    // it in place of `Self`: the type it is applied as, each of its own type
    // parameters standing as `Self.T`, which no signature writes, so a name
    // the contract or a member writes is never the head's. Beside it, the
    // bounds each stands under, and which of the head's names each is.
    var claimed: (type: TypeExpression, bounds: [Name: Set<Name>], standing: [Name: Name])? {
        guard let mention else { return nil }

        let standing = parameterNames.reduce(into: [Name: Name]()) { standing, name in
            standing[name] = Name(normal: "\(TypeSpelling.selfType).\(name)")
        }

        return (
            renamed(mention, by: standing),
            bounds.reduce(into: [:]) { held, entry in
                if let name = standing[entry.key] { held[name] = entry.value }
            },
            standing.reduce(into: [:]) { names, entry in names[entry.value] = entry.key }
        )
    }

    // MARK: - Initializer
    // A parameter bounded by no contract is bounded by nothing, so it stands
    // nowhere in `bounds`.
    public init(_ type: Name, arguments: [TypeExpression] = [], bounds: [Name: Set<Name>] = [:]) {
        self.type = type
        self.arguments = arguments
        self.bounds = bounds.filter { _, contracts in !contracts.isEmpty }
    }

    public init(stringLiteral value: String) {
        self.init(Name(stringLiteral: value))
    }

    // MARK: - Public
    // The head this one stands for where it is bare: its type applied to the
    // type's own parameters, held to the bounds `declared` holds them to, an
    // element for a list and a key and an element for a map. A head applying
    // its type, and a type taking no parameters, stand for themselves.
    func applying(_ declared: TypeDeclaration?) -> Head {
        guard isBare else { return self }

        switch type {
        case TypeSpelling.array:
            return Head(type, arguments: [.parameter(name: TypeSpelling.element)])

        case TypeSpelling.dictionary:
            return Head(
                type,
                arguments: [.parameter(name: TypeSpelling.key), .parameter(name: TypeSpelling.element)],
                bounds: [TypeSpelling.key: [TypeSpelling.hashable]]
            )

        default:
            guard case let .struct(_, typeParameters, bounds)? = declared, !typeParameters.isEmpty else {
                return self
            }

            return Head(type, arguments: typeParameters.map { name in .parameter(name: name) }, bounds: bounds)
        }
    }

    public static func < (lhs: Head, rhs: Head) -> Bool {
        lhs.spelling < rhs.spelling
    }

    // Hashed by its spelling, which two equal heads share.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(spelling)
    }

    // MARK: - Private
    // A type with each of the head's type parameters written under the name
    // `names` gives it.
    private func renamed(_ type: TypeExpression, by names: [Name: Name]) -> TypeExpression {
        switch type {
        case let .parameter(name):
            return .parameter(name: names[name] ?? name)

        case let .named(name, arguments):
            return .named(name, arguments: arguments.map { argument in renamed(argument, by: names) })

        case let .array(element):
            return .array(renamed(element, by: names))

        case let .dictionary(key, value):
            return .dictionary(key: renamed(key, by: names), value: renamed(value, by: names))

        case let .nullable(inner):
            return .nullable(renamed(inner, by: names))

        case let .procedure(procedure?, constness, isolation):
            return .procedure(
                ProcedureType(
                    parameters: procedure.parameters.map { parameter in renamed(parameter, by: names) },
                    returns: procedure.returns.map { returns in renamed(returns, by: names) },
                    failing: procedure.failing
                ),
                constness,
                isolation
            )

        case let .variable(inner):
            return .variable(renamed(inner, by: names))

        case let .inout(inner):
            return .inout(renamed(inner, by: names))

        case let .associatedType(of, name):
            return .associatedType(of: names[of] ?? of, name: name)

        case .any, .never, .null, .bool, .int, .double, .string, .procedure(nil, _, _), .composition, .selfType:
            return type
        }
    }
}

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
// conforms to `Hashable`, and `Array<Int>` every list of integers.
//
// A head applied to nothing is bare and is about every value of the type,
// which is what a struct's declaration gives. An Optional is written by its
// `?` alone, so its head always applies it: `some W?` is every Optional.
public struct Head: Sendable, Hashable, Comparable, ExpressibleByStringLiteral {
    // MARK: - Property
    public let type: Name
    public let arguments: [TypeExpression]
    public let bounds: [Name: Set<Name>]

    public var isBare: Bool { arguments.isEmpty }

    // The one spelling: the type, and what it is applied to between its
    // brackets, each type parameter's bounds written where it is first named.
    public var spelling: Name {
        Name(normal: TypeSyntax(mention ?? .named(type), bounds: bounds).spelling)
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

        case (TypeSpelling.optional, 1):
            return .optional(arguments[0])

        default:
            return .named(type, arguments: arguments)
        }
    }

    // Every declared name this reaches: the type as the head applies it, and
    // the contracts its bounds name.
    var mentions: Set<Name> {
        (mention?.mentions ?? [type]).union(bounds.values.joined())
    }

    // The type parameters the head's arguments name.
    var parameterNames: Set<Name> {
        arguments.reduce(into: []) { names, argument in names.formUnion(argument.parameterNames) }
    }

    // This head with each of its type parameters named by the place it first
    // stands in, so two heads apart only in what they call them are one:
    // `Array<some T>` and `Array<some U>` take the same values.
    public var positional: Head {
        var order: [Name] = []

        for argument in arguments {
            named(in: argument, into: &order)
        }

        let names = order.enumerated().reduce(into: [Name: Name]()) { names, entry in
            names[entry.element] = Name(normal: "\(entry.offset)")
        }

        return Head(
            type,
            arguments: arguments.map { argument in renamed(argument, by: names) },
            bounds: bounds.reduce(into: [:]) { held, entry in held[names[entry.key] ?? entry.key] = entry.value }
        )
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
    // element for a list and a key and an element for a dictionary. A head applying
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
            guard let declared, !declared.typeParameters.isEmpty else { return self }

            return Head(
                type,
                arguments: declared.typeParameters.map { name in .parameter(name: name) },
                bounds: declared.bounds
            )
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
    // Each type parameter `type` names, appended where it first stands.
    private func named(in type: TypeExpression, into order: inout [Name]) {
        switch type {
        case let .parameter(name):
            if !order.contains(name) { order.append(name) }

        case let .associatedType(associated):
            if !order.contains(associated.base) { order.append(associated.base) }

        case let .named(_, arguments):
            for argument in arguments { named(in: argument, into: &order) }

        case let .array(inner), let .optional(inner), let .variable(inner), let .inout(inner),
            let .typeMember(inner, _):
            named(in: inner, into: &order)

        case let .dictionary(key, value):
            named(in: key, into: &order)
            named(in: value, into: &order)

        case let .procedure(procedure?, _, _):
            for parameter in procedure.parameters { named(in: parameter, into: &order) }
            named(in: procedure.returns, into: &order)

        case .any, .never, .null, .bool, .int, .double, .string, .procedure(nil, _, _), .composition, .selfType:
            break
        }
    }

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

        case let .optional(inner):
            return .optional(renamed(inner, by: names))

        case let .procedure(procedure?, constness, isolation):
            return .procedure(
                ProcedureType(
                    parameters: procedure.parameters.map { parameter in renamed(parameter, by: names) },
                    returns: renamed(procedure.returns, by: names),
                    failing: procedure.failing
                ),
                constness,
                isolation
            )

        case let .variable(inner):
            return .variable(renamed(inner, by: names))

        case let .inout(inner):
            return .inout(renamed(inner, by: names))

        case let .typeMember(base, name):
            return .typeMember(renamed(base, by: names), name: name)

        case let .associatedType(associated):
            return .associatedType(AssociatedType(base: names[associated.base] ?? associated.base, members: associated.members))

        case .any, .never, .null, .bool, .int, .double, .string, .procedure(nil, _, _), .composition, .selfType:
            return type
        }
    }
}

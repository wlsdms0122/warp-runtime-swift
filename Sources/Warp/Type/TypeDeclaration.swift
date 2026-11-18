//
//  TypeDeclaration.swift
//  Warp
//
//  Created by JSilver on 10/11/26.
//

import Foundation

// What a module declares a type's name as. A struct is a structure written
// once, here, and read by its name everywhere else: a value of it holds
// exactly these fields and carries the name, so two structs of one structure
// under two names are two types. An alias is a second spelling of a type,
// which every mention reads as what it stands for. An enum is a nominal type
// too, whose values are structs under its cases' spellings.
public enum TypeDeclaration: Sendable, Equatable, CustomStringConvertible {
    // The fields by name. A field written `var` may be written through. A
    // struct may take type parameters, in the order a mention hands it the
    // types it is applied to, each bounded by the contracts `bounds` names
    // under it, as a signature's are; a field writes one as `some T`.
    case `struct`([Name: TypeExpression], typeParameters: [Name] = [], bounds: [Name: Set<Name>] = [:])

    // The cases by name, each beside the fields it carries by name. A case's
    // value is a struct under the case's spelling, `owner.case`. The type
    // parameters and their bounds are a struct's.
    case `enum`([Name: [Name: TypeExpression]], typeParameters: [Name] = [], bounds: [Name: Set<Name>] = [:])

    case alias(TypeExpression)

    // MARK: - Property
    // Whether this declares a nominal type: a struct or an enum, and not a
    // second spelling of another type.
    package var isNominal: Bool {
        switch self {
        case .struct, .enum: true
        case .alias: false
        }
    }

    // The type parameters a struct or an enum lists, in order.
    package var typeParameters: [Name] {
        switch self {
        case let .struct(_, typeParameters, _), let .enum(_, typeParameters, _): typeParameters
        case .alias: []
        }
    }

    // The contracts bounding each type parameter a struct or an enum lists.
    package var bounds: [Name: Set<Name>] {
        switch self {
        case let .struct(_, _, bounds), let .enum(_, _, bounds): bounds
        case .alias: [:]
        }
    }

    // Every declared name this reaches.
    var mentions: Set<Name> {
        switch self {
        case let .struct(fields, _, bounds):
            fields.values.reduce(into: Set(bounds.values.joined())) { mentioned, field in mentioned.formUnion(field.mentions) }

        case let .enum(cases, _, bounds):
            cases.values.joined().reduce(into: Set(bounds.values.joined())) { mentioned, field in
                mentioned.formUnion(field.value.mentions)
            }

        case let .alias(type):
            type.mentions
        }
    }

    // How the declaration reads in a message: a struct as its type
    // parameters, each beside the contracts bounding it, and its fields, each
    // beside its type in name order, an enum as its type parameters and its
    // cases in name order, each beside its fields, and an alias as the type it
    // stands for.
    public var rendered: String {
        switch self {
        case let .struct(fields, typeParameters, bounds):
            return "\(Self.taking(typeParameters, bounds: bounds)){ \(Self.rendered(fields)) }"

        case let .enum(cases, typeParameters, bounds):
            let written = cases
                .sorted { left, right in left.key < right.key }
                .map { name, fields in fields.isEmpty ? "\(name)" : "\(name) { \(Self.rendered(fields)) }" }

            return "\(Self.taking(typeParameters, bounds: bounds))enum { \(written.joined(separator: ", ")) }"

        case let .alias(type):
            return type.rendered
        }
    }

    public var description: String { rendered }

    // MARK: - Initializer
    // MARK: - Public
    // The spelling of each case an enum declares under `name`, the enum's
    // own: the enum's name and the case's with a dot. None for a struct or an
    // alias.
    package func caseSpellings(under name: Name) -> [Name] {
        guard case let .enum(cases, _, _) = self else { return [] }

        return cases.keys.map { label in label.spelled(under: name) }
    }

    // MARK: - Private
    private static func rendered(_ fields: [Name: TypeExpression]) -> String {
        fields
            .sorted { left, right in left.key < right.key }
            .map { name, field in "\(name): \(field.rendered)" }
            .joined(separator: ", ")
    }

    private static func taking(_ typeParameters: [Name], bounds: [Name: Set<Name>]) -> String {
        let parameters = typeParameters.map { parameter in
            TypeSyntax.Introduced(parameter.spelling, bound: bounds[parameter].map(TypeSyntax.Bound.init)).spelling
        }

        return typeParameters.isEmpty ? "" : "<\(parameters.joined(separator: ", "))> "
    }
}

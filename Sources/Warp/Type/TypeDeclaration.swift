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
// which every mention reads as what it stands for.
public enum TypeDeclaration: Sendable, Equatable, CustomStringConvertible {
    // The fields by name. A field written `var` may be written through. A
    // struct may take type parameters, in the order a mention hands it the
    // types it is applied to, each bounded by the contracts `bounds` names
    // under it, as a signature's are; a field writes one as `some T`.
    case `struct`([Name: TypeExpression], typeParameters: [Name] = [], bounds: [Name: Set<Name>] = [:])

    case alias(TypeExpression)

    // MARK: - Property
    // Every declared name this reaches.
    var mentions: Set<Name> {
        switch self {
        case let .struct(fields, _, bounds):
            fields.values.reduce(into: Set(bounds.values.joined())) { mentioned, field in mentioned.formUnion(field.mentions) }

        case let .alias(type):
            type.mentions
        }
    }

    // How the declaration reads in a message: a struct as its type
    // parameters, each beside the contracts bounding it, and its fields, each
    // beside its type in name order, and an alias as the type it stands for.
    public var rendered: String {
        switch self {
        case let .struct(fields, typeParameters, bounds):
            let written = fields
                .sorted { left, right in left.key < right.key }
                .map { name, field in "\(name): \(field.rendered)" }
            let parameters = typeParameters.map { parameter in
                bounds[parameter].map { contracts in "\(parameter): \(contracts.sorted().map(\.spelling).joined(separator: " & "))" }
                    ?? parameter.spelling
            }
            let taking = typeParameters.isEmpty ? "" : "<\(parameters.joined(separator: ", "))> "

            return "\(taking){ \(written.joined(separator: ", ")) }"

        case let .alias(type):
            return type.rendered
        }
    }

    public var description: String { rendered }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

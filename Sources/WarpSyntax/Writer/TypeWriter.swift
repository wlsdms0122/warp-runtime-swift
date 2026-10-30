//
//  TypeWriter.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A type written the way `TypeReader` reads it: its spelling, kept only where
// the reading takes it back as the same type.
struct TypeWriter {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A spelling is kept only where the reading takes it back as this type.
    func value(of type: TypeExpression) throws -> Value {
        try value(of: TypeSyntax(type), as: type)
    }

    // A slot's type, written as its syntax, where a bound may stand beside
    // the first naming of a type parameter: kept only where the reading
    // takes the spelling back as the type.
    func value(of syntax: TypeSyntax, as type: TypeExpression) throws -> Value {
        let spelling = syntax.spelling
        let read: TypeExpression

        do {
            read = try TypeReader().written(spelling).type
        } catch {
            throw WritingError("the type is written '\(spelling)', which the reading refuses: \(error)")
        }

        guard read == type else {
            throw WritingError(
                "the type is written '\(spelling)', which the reading takes as \(read.rendered),"
                    + " and a document has no way to tell the two apart"
            )
        }

        return .string(spelling)
    }

    // A declared type: a struct under `struct`, its fields beside their
    // types, the type parameters it takes beside their bounds where it takes
    // any, and an alias as the type it stands for.
    func value(of declared: TypeDeclaration) throws -> Value {
        switch declared {
        case let .struct(fields, typeParameters, bounds):
            var written: [Name: Value] = [TypeDeclarationReader.structKey: .dictionary(try fields.mapValues(value(of:)))]

            if !typeParameters.isEmpty || !bounds.isEmpty {
                written[TypeDeclarationReader.typeParametersKey] = introduced(typeParameters, bounds: bounds)
            }

            return .dictionary(written)

        case let .alias(type):
            return try value(of: type)
        }
    }

    // Names a list introduces, a struct's type parameters or the types a
    // contract asks, each beside the contracts it is bounded by.
    func introduced(_ names: [Name], bounds: [Name: Set<Name>]) -> Value {
        .array(
            names.map { name in
                .string(TypeSyntax.Introduced(name.spelling, bound: bounds[name].map(TypeSyntax.Bound.init)).spelling)
            }
        )
    }

    // What a signature bounds that it does not introduce, an associated type
    // of one of its type parameters, under its label, or nothing where it
    // bounds none.
    func labeled(_ bounds: [Name: Set<Name>]) -> Value? {
        guard !bounds.isEmpty else { return nil }

        return .dictionary(bounds.mapValues { contracts in .string(TypeSyntax.Bound(contracts).spelling) })
    }

    // MARK: - Private
}

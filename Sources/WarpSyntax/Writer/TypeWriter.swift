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
    // The bounds a signature's slots write, each beside the first naming of
    // its type parameter, as the reading takes them: the slots in order, at
    // any depth.
    final class Introducing {
        // MARK: - Property
        // What is left to write.
        private(set) var bounds: [Name: Set<Name>]
        private var named: Set<Name> = []

        // MARK: - Initializer
        init(_ bounds: [Name: Set<Name>]) {
            self.bounds = bounds
        }

        // MARK: - Public
        // The bound written beside this naming, at the first one only.
        func bound(at name: Name) -> Set<Name>? {
            guard named.insert(name).inserted else { return nil }

            return bounds.removeValue(forKey: name)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // Who reads the spelling back, which says what a declared name written
    // short stands for.
    let readBy: Notation

    // MARK: - Initializer
    // MARK: - Public
    // A spelling is kept only where the reading takes it back as this type.
    func value(of type: TypeExpression) throws -> Value {
        try value(of: type, introducing: nil)
    }

    // The same in a signature's slot, where a bound stands beside the first
    // naming of its type parameter.
    func value(of type: TypeExpression, introducing: Introducing?) throws -> Value {
        try checked(type.spelled { name in introducing?.bound(at: name) }, as: type)
    }

    // A declared type: a struct under `struct`, its fields beside their
    // types, the type parameters it takes beside their bounds where it takes
    // any, and an alias as the type it stands for.
    func value(of declared: TypeDeclaration) throws -> Value {
        switch declared {
        case let .struct(fields, typeParameters, bounds):
            var written: [Name: Value] = [TypeDeclarationReader.structKey: .dictionary(try fields.mapValues(value(of:)))]

            if !typeParameters.isEmpty || !bounds.isEmpty {
                written[TypeDeclarationReader.typeParametersKey] = try introduced(typeParameters, bounds: bounds)
            }

            return .dictionary(written)

        case let .alias(type):
            return try value(of: type)
        }
    }

    // Names a list introduces, a struct's type parameters or the types a
    // contract asks, each beside the contracts it is bounded by, joined with
    // `&`. A bound on a name the list does not hold has nowhere to stand.
    func introduced(_ names: [Name], bounds: [Name: Set<Name>]) throws -> Value {
        if let unwritten = Set(bounds.keys).subtracting(names).min() {
            throw WritingError("bounds '\(unwritten)', which the list does not hold, and a bound stands beside its name")
        }

        return .array(
            names.map { name in
                guard let contracts = bounds[name] else { return .string(name.spelling) }

                return .string("\(name.spelling): \(Self.joined(contracts))")
            }
        )
    }

    // What a signature bounds that it does not introduce, an associated type
    // of one of its type parameters, under its label, or nothing where it
    // bounds none.
    func labeled(_ bounds: [Name: Set<Name>]) -> Value? {
        guard !bounds.isEmpty else { return nil }

        return .dictionary(bounds.mapValues { contracts in .string(Self.joined(contracts)) })
    }

    // MARK: - Private
    // A bound's contracts, in one order.
    private static func joined(_ contracts: Set<Name>) -> String {
        contracts.sorted().map(\.spelling).joined(separator: " & ")
    }

    // A written type, where the spelling is one the reading takes back as the
    // type.
    private func checked(_ spelling: String, as type: TypeExpression) throws -> Value {
        let read: TypeExpression

        do {
            read = try TypeReader.reading(spelling, in: readBy).bounded.type
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
}

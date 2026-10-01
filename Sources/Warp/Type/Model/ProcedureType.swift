//
//  ProcedureType.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// What a slot asks of a procedure value: the types it is applied with, in
// position order, and what it answers. No names. A name is a declaration's or
// a closure's, read by its body; a value is applied by position, so two
// closures that name their parameters differently are one type where the
// types agree.
public struct ProcedureType: Sendable, Equatable {
    // MARK: - Property
    // Each parameter's type, marks included, since `inout`, `consuming` and
    // `borrowing` are facts about the slot a value is applied through.
    public let parameters: [TypeExpression]

    // What an application answers, or nil where nothing was declared.
    public let returns: TypeExpression?

    // Every declared name this type reaches, through what it takes and what
    // it answers.
    var mentions: Set<Name> {
        parameters.reduce(into: returns?.mentions ?? []) { mentioned, parameter in
            mentioned.formUnion(parameter.mentions)
        }
    }

    // The positions taking their argument in place.
    var inPlacePositions: Set<Int> {
        Set(parameters.indices.filter { position in parameters[position].isInout })
    }

    // Whether a type parameter stands anywhere in its parameters or answer.
    public var isGeneric: Bool {
        parameters.contains { parameter in parameter.isGeneric }
            || (returns?.isGeneric ?? false)
    }

    // Every type parameter mentioned in this type, occurrence by occurrence.
    public var parameterOccurrences: [ParameterOccurrence] {
        parameters.flatMap { parameter in parameter.parameterOccurrences }
            + (returns?.parameterOccurrences ?? [])
    }

    // What this type holds its type parameters to, read off every occurrence.
    public var parameterBounds: ParameterBounds {
        ParameterBounds(parameterOccurrences)
    }

    // MARK: - Initializer
    public init(parameters: [TypeExpression] = [], returns: TypeExpression? = nil) {
        self.parameters = parameters
        self.returns = returns
    }

    // MARK: - Public
    // This type with each occurrence carrying the bound declared for its
    // name. The one `bounds` at the declaration speaks for a nested type.
    public func bounded(by bounds: [Name: [Name]]) -> ProcedureType {
        ProcedureType(
            parameters: parameters.map { parameter in parameter.bounded(by: bounds) },
            returns: returns?.bounded(by: bounds)
        )
    }

    // MARK: - Private
}

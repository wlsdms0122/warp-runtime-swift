//
//  ProcedureType.swift
//  Warp
//
//  Created by JSilver on 9/23/26.
//

import Foundation

// What a slot asks of a procedure value: the types it is applied with, in
// position order, what it answers and what may come out of it when the work
// goes wrong. No names. A name is a declaration's or a closure's, read by its
// body; a value is applied by position, so two closures that name their
// parameters differently are one type where the types agree.
public struct ProcedureType: Sendable, Equatable {
    // MARK: - Property
    // Each parameter's type, marks included, since `inout` is a fact about the
    // slot a value is applied through.
    public let parameters: [TypeExpression]

    // What an application answers.
    public let returns: TypeExpression

    // What an application may fail with: anything, written `throws`, or the
    // failures listed, none written as no `throws`.
    public let failing: Failing

    // Every declared name this type reaches, through what it takes and what
    // it answers.
    var mentions: Set<Name> {
        parameters.reduce(into: returns.mentions) { mentioned, parameter in
            mentioned.formUnion(parameter.mentions)
        }
    }

    // The positions taking their argument in place.
    var inPlacePositions: Set<Int> {
        Set(parameters.indices.filter { position in parameters[position].isInout })
    }

    // Whether a type parameter stands anywhere in its parameters or answer.
    var isGeneric: Bool {
        parameters.contains { parameter in parameter.isGeneric }
            || returns.isGeneric
    }

    // Every type parameter named in its parameters or answer.
    var parameterNames: Set<Name> {
        parameters.reduce(into: returns.parameterNames) { named, parameter in
            named.formUnion(parameter.parameterNames)
        }
    }

    // MARK: - Initializer
    public init(parameters: [TypeExpression] = [], returns: TypeExpression, failing: Failing) {
        self.parameters = parameters
        self.returns = returns
        self.failing = failing
    }

    // MARK: - Public
    // The same type failing with `failing` instead.
    func with(failing: Failing) -> ProcedureType {
        ProcedureType(parameters: parameters, returns: returns, failing: failing)
    }

    // This type with `Self` written as `type` wherever it stands.
    func replacingSelf(with type: TypeExpression) -> ProcedureType {
        ProcedureType(
            parameters: parameters.map { parameter in parameter.replacingSelf(with: type) },
            returns: returns.replacingSelf(with: type),
            failing: failing
        )
    }

    // MARK: - Private
}

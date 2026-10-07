//
//  TypeExpression+Completing.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

extension TypeExpression {
    // A closure literal written where this is declared, its signature
    // completed by the place: one that writes no `returns`, written where a
    // procedure type says what it answers, answers that, so its body is
    // judged against it and a literal it answers is read as the place reads
    // it. An answer the call fills is no place's to say, and anything else
    // stands as written.
    func completing(_ expression: Expression, in types: TypeTable) -> Expression {
        guard
            case let .closure(written) = expression,
            written.signature.returns == nil,
            let returns = procedureAnswer(in: types),
            !returns.isGeneric
        else {
            return expression
        }

        return .closure(written.with(signature: Signature(parameters: written.signature.parameters, returns: returns)))
    }

    // What a procedure type standing here says it answers, through the names
    // and the `?` around it, and nil where this holds no procedure type or
    // one that says nothing of its answer.
    private func procedureAnswer(in types: TypeTable) -> TypeExpression? {
        switch slotUnwrapped.fieldUnwrapped.resolved(in: types) {
        case let .procedure(type?, _, _):
            return type.returns

        case let .nullable(inner):
            return inner.procedureAnswer(in: types)

        default:
            return nil
        }
    }
}

//
//  CheckedCall.swift
//  Warp
//
//  Created by JSilver on 10/9/26.
//

import Foundation

// The call a judgement stands around, of one of the three kinds a call is:
// one to a declaration, one through a contract, and one of a value.
enum CheckedCall: Sendable {
    case call(CallOperation)
    case dispatch(DispatchOperation)
    case apply(Operation, arguments: [Argument])

    // MARK: - Property
    // The call as an operation of its own.
    var operation: Operation {
        switch self {
        case let .call(call):
            return .call(call)

        case let .dispatch(dispatch):
            return .dispatch(dispatch)

        case let .apply(callee, arguments):
            return .apply(callee, arguments: arguments)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // The same call with what nests in it rewritten. The call itself is the
    // judgement's to rewrite, since the two stand as one node.
    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> CheckedCall {
        switch self {
        case let .call(call):
            return .call(try call.rewritten(operation: operation, type: type))

        case let .dispatch(dispatch):
            return .dispatch(try dispatch.rewritten(operation: operation, type: type))

        case let .apply(callee, arguments):
            return .apply(
                try callee.rewritten(operation: operation, type: type),
                arguments: try arguments.map { argument in try argument.rewritten(operation: operation, type: type) }
            )
        }
    }

    // MARK: - Private
}

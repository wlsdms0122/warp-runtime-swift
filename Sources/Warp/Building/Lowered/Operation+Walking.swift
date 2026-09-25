//
//  Operation+Walking.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Operation {
    @discardableResult
    func walk(_ visit: (Body.Node) -> Bool) -> Bool {
        guard visit(.operation(self)) else { return false }

        switch self {
        case .literal, .local, .closure:
            return true

        case let .array(elements):
            return elements.allSatisfy { element in element.walk(visit) }

        case let .record(held):
            return held.fields.allSatisfy { field in field.walk(visit) }

        case let .apply(callee, arguments):
            return callee.walk(visit) && arguments.allSatisfy { argument in argument.walk(visit) }

        case let .cast(read, _, _):
            return read.walk(visit)

        case let .block(body):
            return body.walk(visit)

        case let .conditional(condition, then, otherwise):
            return condition.walk(visit)
                && then.allSatisfy { instruction in instruction.walk(visit) }
                && (otherwise?.allSatisfy { instruction in instruction.walk(visit) } ?? true)

        case let .loop(condition, body, _, _):
            return condition.walk(visit) && body.walk(visit)

        case let .attempt(body, rescue, _):
            return body.walk(visit) && rescue.walk(visit)

        case let .call(call):
            return call.arguments.allSatisfy { argument in argument?.walk(visit) ?? true }

        // What a call through a contract hands over is its first and its
        // `arguments`. The
        // calls beside it are the link's copy of the same, so walking those
        // too would read one fact twice. An argument handed in place is a
        // place and not an operation, and a place is the node's own to read.
        case let .dispatch(dispatch):
            return dispatch.first.walk(visit)
                && dispatch.arguments.allSatisfy { argument in
                    guard case let .value(operation) = argument else { return true }

                    return operation.walk(visit)
                }

        case let .leave(_, _, read):
            return read?.walk(visit) ?? true
        }
    }

    func contains(where predicate: (Body.Node) -> Bool) -> Bool {
        !walk { node in !predicate(node) }
    }
}

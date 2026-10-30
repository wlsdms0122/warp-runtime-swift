//
//  Operation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A body as the run reads it: the document's expression with every fact the
// build proved written in. A name is the frame slot the build gave it, a
// selector is the number of the row it named, and an argument stands at
// the position of the parameter it fills. What only a run can know, the type
// of a value or the signature of a closure value, is asked at the run.
indirect enum Operation: Sendable {
    case literal(Value)

    // A slot of the frame, read through a path.
    case local(Address)

    case array([Operation])

    case `struct`(StructOperation)

    // A dictionary literal: each entry's key and value, in the order written, so a
    // key written twice keeps the later value.
    case dictionary([(key: Operation, value: Operation)])

    // A closure literal: the number its document gave the row its body was
    // lowered into, and which cells of the frame it takes with it, as
    // (outer slot, inner slot).
    case closure(Int, captures: [(Int, Int)])

    // Calling a value. The arguments are positional and handed to the
    // closure's slots as they were read; one the build found handed in place
    // is the caller's place.
    case apply(Operation, arguments: [Argument])

    case cast(Operation, as: LoweredType, optional: Bool)

    // A value where its reading meets a place that reads it another way,
    // and what becomes of it there. A type the coercion names may name a
    // type parameter of the body.
    case coerced(Operation, Coercion)

    case conditional(Operation, then: [Instruction], else: [Instruction]?)

    // The round's slot, where the statement bound one.
    case loop(while: Operation, body: [Instruction], round: Int?)

    // The failure's slot, where the statement bound one.
    case `try`([Instruction], catch: [Instruction], failure: Int?)

    // The payload's slot, where `then` reads one under the statement's
    // name. With no `then` the unwrap gives the payload, and the statement
    // binds it.
    case unwrap(Operation, then: [Instruction]?, else: [Instruction]?, payload: Int?)
    case call(CallOperation)

    // A call through a contract: which row satisfies it is the type that
    // fills `Self` to say, and the link laid out one call per type that
    // conforms.
    case dispatch(DispatchOperation)
    case leave(LeaveOperation)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    @discardableResult
    func walk(_ visit: (LoweredBody.Node) -> Bool) -> Bool {
        guard visit(.operation(self)) else { return false }

        switch self {
        case .literal, .local, .closure, .leave(.loop), .leave(.round):
            return true

        case let .array(elements):
            return elements.allSatisfy { element in element.walk(visit) }

        case let .struct(held):
            return held.fields.allSatisfy { field in field.walk(visit) }

        case let .dictionary(entries):
            return entries.allSatisfy { entry in entry.key.walk(visit) && entry.value.walk(visit) }

        // An argument handed in place is a place and not an operation, and a
        // place is the node's own to read.
        case let .apply(callee, arguments):
            return callee.walk(visit)
                && arguments.allSatisfy { argument in
                    guard case let .value(operation) = argument else { return true }

                    return operation.walk(visit)
                }

        case let .cast(read, _, _), let .coerced(read, _):
            return read.walk(visit)

        case let .conditional(condition, then, otherwise):
            return condition.walk(visit)
                && then.allSatisfy { instruction in instruction.walk(visit) }
                && (otherwise?.allSatisfy { instruction in instruction.walk(visit) } ?? true)

        case let .loop(condition, body, _):
            return condition.walk(visit) && body.allSatisfy { instruction in instruction.walk(visit) }

        case let .try(body, `catch`, _):
            return body.allSatisfy { instruction in instruction.walk(visit) }
                && `catch`.allSatisfy { instruction in instruction.walk(visit) }

        case let .unwrap(read, then, otherwise, _):
            return read.walk(visit)
                && (then?.allSatisfy { instruction in instruction.walk(visit) } ?? true)
                && (otherwise?.allSatisfy { instruction in instruction.walk(visit) } ?? true)

        case let .call(call):
            return call.placed.arguments.allSatisfy { argument in argument?.walk(visit) ?? true }

        // What a call through a contract hands over is its first and its
        // `arguments`. The calls beside it are the link's copy of the same, so
        // walking those too would read one fact twice. An argument handed in
        // place is a place and not an operation, and a place is the node's own
        // to read.
        case let .dispatch(dispatch):
            return ([dispatch.first] + dispatch.arguments).allSatisfy { argument in
                guard case let .value(operation) = argument else { return true }

                return operation.walk(visit)
            }

        case let .leave(.procedure(returned)):
            return returned?.walk(visit) ?? true
        }
    }

    func contains(where predicate: (LoweredBody.Node) -> Bool) -> Bool {
        !walk { node in !predicate(node) }
    }

    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> Operation {
        let inside: Operation

        switch self {
        case .literal, .closure, .leave(.loop), .leave(.round):
            inside = self

        case let .local(address):
            inside = .local(try address.rewritten(type: type))

        case let .array(elements):
            inside = .array(try elements.map { element in try element.rewritten(operation: operation, type: type) })

        case let .struct(held):
            inside = .struct(
                StructOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try field.rewritten(operation: operation, type: type) }
                )
            )

        case let .dictionary(entries):
            inside = .dictionary(
                try entries.map { entry in
                    (
                        key: try entry.key.rewritten(operation: operation, type: type),
                        value: try entry.value.rewritten(operation: operation, type: type)
                    )
                }
            )

        case let .apply(callee, arguments):
            inside = .apply(
                try callee.rewritten(operation: operation, type: type),
                arguments: try arguments.map { argument in
                    try argument.rewritten(operation: operation, type: type)
                }
            )

        case let .cast(read, cast, optional):
            inside = .cast(
                try read.rewritten(operation: operation, type: type),
                as: try type(cast),
                optional: optional
            )

        case let .coerced(read, coercion):
            inside = .coerced(try read.rewritten(operation: operation, type: type), try coercion.rewritten(type: type))

        case let .conditional(condition, then, otherwise):
            inside = .conditional(
                try condition.rewritten(operation: operation, type: type),
                then: try then.map { instruction in try instruction.rewritten(operation: operation, type: type) },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try instruction.rewritten(operation: operation, type: type) }
                }
            )

        case let .loop(condition, body, round):
            inside = .loop(
                while: try condition.rewritten(operation: operation, type: type),
                body: try body.map { instruction in try instruction.rewritten(operation: operation, type: type) },
                round: round
            )

        case let .try(body, `catch`, failure):
            inside = .try(
                try body.map { instruction in try instruction.rewritten(operation: operation, type: type) },
                catch: try `catch`.map { instruction in try instruction.rewritten(operation: operation, type: type) },
                failure: failure
            )

        case let .unwrap(read, then, otherwise, payload):
            inside = .unwrap(
                try read.rewritten(operation: operation, type: type),
                then: try then.map { instructions in
                    try instructions.map { instruction in try instruction.rewritten(operation: operation, type: type) }
                },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try instruction.rewritten(operation: operation, type: type) }
                },
                payload: payload
            )

        case let .call(call):
            inside = .call(try call.rewritten(operation: operation, type: type))

        case let .dispatch(dispatch):
            inside = .dispatch(try dispatch.rewritten(operation: operation, type: type))

        case let .leave(.procedure(returned)):
            inside = .leave(.procedure(try returned.map { returned in try returned.rewritten(operation: operation, type: type) }))
        }

        return try operation(inside)
    }

    // MARK: - Private
}

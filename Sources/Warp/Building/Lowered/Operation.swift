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
// of a value or the signature of a closure value, is still asked at the run.
indirect enum Operation: Sendable {
    case literal(Value)

    // A slot of the frame, read through a path.
    case local(Address)

    case array([Operation])

    case record(RecordOperation)

    // A closure literal: the number its document gave the row its body was
    // lowered into, and which cells of the frame it takes with it, as
    // (outer slot, inner slot).
    case closure(Int, captures: [(Int, Int)])

    // Calling a value. The arguments are positional and settle against the
    // closure's own row. One the build found handed in place is the caller's
    // place.
    case apply(Operation, arguments: [Argument])

    case cast(Operation, as: LoweredType, optional: Bool)

    // A call's answer judged against what the call reads it as, where the
    // callee settles a wider one: a type parameter the call filled, the
    // `returns` a value's slot wrote, a contract's answer. Refused at the run
    // the way a value arriving at a parameter is, and handed on as it came:
    // the callee already shaped it to what it declared, and a reading takes a
    // value it admits as that value, a whole number where a fraction is read
    // included, which is what lets a tie answer the side that arrived. Nothing
    // after it stands on this type's shape: a field read stands on the call
    // inside, and a binding or a parameter that declares a type settles the
    // value where it lands. Nil where only what the call handed back in place
    // is judged. Each variable it handed back is judged once the call is over,
    // whether it answered or failed.
    case checked(Operation, against: LoweredType?, handedBack: [HandedBack])

    case block(LoweredBody)
    case conditional(Operation, then: [Instruction], else: [Instruction]?)

    // `keeps` is the range of body slots the result reads: the result reads
    // what the last finished round bound, so a round cut short is put back
    // before the result reads. Nil where the result reads none of them.
    // The round's slot, where the statement bound one.
    case loop(while: Operation, body: LoweredBody, round: Int?, keeps: Range<Int>?)

    case attempt(LoweredBody, rescue: LoweredBody, failure: Int?)
    case call(CallOperation)

    // A call through a contract: which row answers is the first argument's
    // own name to say, and the link laid out one call per type that answers.
    case dispatch(DispatchOperation)
    case leave(Leave.Reach, target: Name?, Operation?)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Whether this reads any slot in the range, through a path's index
    // references as well. A closure's captures are reads of its own.
    func reads(_ slots: Range<Int>) -> Bool {
        contains { node in node.reads(slots) }
    }

    @discardableResult
    func walk(_ visit: (LoweredBody.Node) -> Bool) -> Bool {
        guard visit(.operation(self)) else { return false }

        switch self {
        case .literal, .local, .closure:
            return true

        case let .array(elements):
            return elements.allSatisfy { element in element.walk(visit) }

        case let .record(held):
            return held.fields.allSatisfy { field in field.walk(visit) }

        // An argument handed in place is a place and not an operation, and a
        // place is the node's own to read.
        case let .apply(callee, arguments):
            return callee.walk(visit)
                && arguments.allSatisfy { argument in
                    guard case let .value(operation) = argument else { return true }

                    return operation.walk(visit)
                }

        case let .cast(read, _, _), let .checked(read, _, _):
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
        // `arguments`. The calls beside it are the link's copy of the same, so walking those
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

    func contains(where predicate: (LoweredBody.Node) -> Bool) -> Bool {
        !walk { node in !predicate(node) }
    }

    func rewritten(
        operation: (Operation) throws -> Operation,
        type: (LoweredType) throws -> LoweredType
    ) rethrows -> Operation {
        let inside: Operation

        switch self {
        case .literal, .local, .closure:
            inside = self

        case let .array(elements):
            inside = .array(try elements.map { element in try element.rewritten(operation: operation, type: type) })

        case let .record(held):
            inside = .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try field.rewritten(operation: operation, type: type) }
                )
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

        case let .checked(read, against, handedBack):
            inside = .checked(
                try read.rewritten(operation: operation, type: type),
                against: try against.map(type),
                handedBack: try handedBack.map { back in HandedBack(position: back.position, against: try type(back.against)) }
            )

        case let .block(body):
            inside = .block(try body.rewritten(operation: operation, type: type))

        case let .conditional(condition, then, otherwise):
            inside = .conditional(
                try condition.rewritten(operation: operation, type: type),
                then: try then.map { instruction in try instruction.rewritten(operation: operation, type: type) },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try instruction.rewritten(operation: operation, type: type) }
                }
            )

        case let .loop(condition, body, round, keeps):
            inside = .loop(
                while: try condition.rewritten(operation: operation, type: type),
                body: try body.rewritten(operation: operation, type: type),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            inside = .attempt(
                try body.rewritten(operation: operation, type: type),
                rescue: try rescue.rewritten(operation: operation, type: type),
                failure: failure
            )

        case let .call(call):
            inside = .call(
                CallOperation(
                    procedure: call.procedure,
                    arguments: try call.arguments.map { argument in
                        try argument.map { argument in try argument.rewritten(operation: operation, type: type) }
                    },
                    handed: call.handed
                )
            )

        // The calls beside a dispatch are the link's to lay out, so they are
        // handed over as they stand for the relocation to answer.
        case let .dispatch(dispatch):
            inside = .dispatch(
                DispatchOperation(
                    contract: dispatch.contract,
                    procedure: dispatch.procedure,
                    first: try dispatch.first.rewritten(operation: operation, type: type),
                    arguments: try dispatch.arguments.map { argument in
                        try argument.rewritten(operation: operation, type: type)
                    },
                    calls: dispatch.calls
                )
            )

        case let .leave(reach, target, read):
            inside = .leave(reach, target: target, try read.map { read in try read.rewritten(operation: operation, type: type) })
        }

        return try operation(inside)
    }

    // MARK: - Private
}

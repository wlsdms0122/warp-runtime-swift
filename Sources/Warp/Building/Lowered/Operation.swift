//
//  Operation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A body as the run reads it: the document's expression with every fact the
// link proved written in. A name is the frame slot the link gave it, a
// selector is the row of the linked table it named, and an argument stands at
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

    // Calling a value. Which signature it has is the value's, so the
    // arguments travel by name and settle where the closure is known.
    case apply(Operation, arguments: [Operation])

    case cast(Operation, as: LoweredType, optional: Bool)
    case block(Body)
    case conditional(Operation, then: [Instruction], else: [Instruction]?)

    // `keeps` is the range of body slots the result reads: the result reads
    // what the last finished round bound, so a round cut short is put back
    // before the result reads. Nil where the result reads none of them.
    // The round's slot, and the failure's, where the statement bound one.
    case loop(while: Operation, body: Body, round: Int?, keeps: Range<Int>?)

    case attempt(Body, rescue: Body, failure: Int?)
    case call(CallOperation)

    // A call through a contract: which row answers is the receiver's own name
    // to say, and the link laid out one call per type that answers.
    case dispatch(DispatchOperation)
    case leave(Leave.Reach, target: Name?, Operation?)
}

extension Operation {
    // Whether this reads any slot in the range, through a path's index
    // references as well. A closure's captures are reads of its own.
    func reads(_ slots: Range<Int>) -> Bool {
        contains { node in node.reads(slots) }
    }
}

extension Body.Node {
    // Whether this one node reads a slot of the range, apart from what nests
    // in it. A further question over the same shape as `stand`, and it stays
    // apart: this counts only the slots a body's value depends on, and leaves
    // out the ones it binds.
    func reads(_ slots: Range<Int>) -> Bool {
        switch self {
        case let .instruction(instruction):
            guard case let .assign(address, _)? = instruction.binding else { return false }

            return address.reads(slots)

        case let .operation(operation):
            switch operation {
            case let .local(address):
                return address.reads(slots)

            case let .closure(_, captures):
                return captures.contains { outer, _ in slots.contains(outer) }

            case let .call(call):
                return call.handed.contains { handed in handed.address.reads(slots) }

            case let .dispatch(dispatch):
                return dispatch.arguments.values.contains { argument in
                    guard case let .reference(address) = argument else { return false }

                    return address.reads(slots)
                }

            case .literal, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
                return false
            }
        }
    }
}

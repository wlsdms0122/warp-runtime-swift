//
//  Operation.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A body as the run reads it: the document's expression with every fact the
// link proved written in. A name is the frame slot the link gave it, a
// selector is the row of the linked table it named, a path word is the row
// it sends, and an argument stands at the position of the parameter it fills.
// What only a run can know, the shape of a value or the signature of a
// closure value, is still asked at the run.
indirect enum Operation: Sendable {
    case literal(Value)

    // A slot of the frame, read through a path.
    case local(Int, [Step])

    case array([Operation])

    case record(RecordOperation)

    // A closure literal: the row its body was lowered into, and which cells
    // of the frame it takes with it, as (outer slot, inner slot).
    case closure(Linked, captures: [(Int, Int)])

    // Calling a value. Which signature it has is the value's, so the
    // arguments travel by name and settle where the closure is known.
    case apply(Operation, arguments: [(Name, Operation)])

    case cast(Operation, as: Shape, optional: Bool)
    case block(Body)
    case conditional(Operation, then: [Instruction], else: [Instruction]?)

    // `keeps` is the range of body slots the result reads: the result reads
    // what the last finished round bound, so a round cut short is put back
    // before the result reads. Nil where the result reads none of them.
    case loop(while: Operation, body: Body, round: Int, keeps: Range<Int>?)

    case attempt(Body, rescue: Body, failure: Int)
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
        switch self {
        case .literal:
            return false

        case let .local(slot, steps):
            return slots.contains(slot) || steps.contains { step in step.reads(slots) }

        case let .array(elements):
            return elements.contains { element in element.reads(slots) }

        case let .record(held):
            return held.fields.contains { field in field.reads(slots) }

        case let .closure(_, captures):
            return captures.contains { outer, _ in slots.contains(outer) }

        case let .apply(callee, arguments):
            return callee.reads(slots) || arguments.contains { _, argument in argument.reads(slots) }

        case let .cast(value, _, _):
            return value.reads(slots)

        case let .block(body):
            return body.reads(slots)

        case let .conditional(condition, then, otherwise):
            return condition.reads(slots)
                || then.contains { instruction in instruction.reads(slots) }
                || otherwise?.contains { instruction in instruction.reads(slots) } == true

        case let .loop(condition, body, _, _):
            return condition.reads(slots) || body.reads(slots)

        case let .attempt(body, rescue, _):
            return body.reads(slots) || rescue.reads(slots)

        case let .call(call):
            return call.receiver?.reads(slots) == true
                || call.arguments.contains { argument in argument?.reads(slots) == true }
                || call.handed.contains { handed in
                    slots.contains(handed.slot) || handed.path.contains { step in step.reads(slots) }
                }

        case let .dispatch(dispatch):
            return dispatch.receiver.reads(slots)
                || dispatch.calls.values.contains { call in
                    call.arguments.contains { argument in argument?.reads(slots) == true }
                        || call.handed.contains { handed in
                            slots.contains(handed.slot) || handed.path.contains { step in step.reads(slots) }
                        }
                }

        case let .leave(_, _, value):
            return value?.reads(slots) == true
        }
    }
}

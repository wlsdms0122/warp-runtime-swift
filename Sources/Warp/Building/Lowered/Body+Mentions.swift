//
//  Body+Mentions.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// Whether a body names a frame slot at or above a position.
//
// `reads` asks which slots a body's value depends on, and leaves out the ones
// it only writes. This asks which it names at all, so a frame that does not
// hold every slot its body stands on is a frame the body does not fit. The
// two are one traversal in shape and two questions in what they count.
extension Body {
    func mentions(atOrAbove position: Int) -> Bool {
        instructions.contains { instruction in instruction.mentions(atOrAbove: position) }
            || result?.mentions(atOrAbove: position) == true
    }
}

extension Instruction {
    func mentions(atOrAbove position: Int) -> Bool {
        switch binding {
        case let .bind(slot, _)?, let .declare(slot, _)?:
            if slot >= position { return true }

        case let .assign(address, _)?:
            if address.mentions(atOrAbove: position) { return true }

        case nil:
            break
        }

        return code.mentions(atOrAbove: position)
    }
}

extension Address {
    func mentions(atOrAbove position: Int) -> Bool {
        slot >= position || steps.contains { step in step.mentions(atOrAbove: position) }
    }
}

extension Step {
    func mentions(atOrAbove position: Int) -> Bool {
        guard case let .at(address, _) = self else { return false }

        return address.mentions(atOrAbove: position)
    }
}

extension Argument {
    func mentions(atOrAbove position: Int) -> Bool {
        switch self {
        case let .value(operation):
            return operation.mentions(atOrAbove: position)

        case let .reference(address):
            return address.mentions(atOrAbove: position)
        }
    }
}

extension Operation {
    func mentions(atOrAbove position: Int) -> Bool {
        switch self {
        case .literal:
            return false

        case let .local(address):
            return address.mentions(atOrAbove: position)

        case let .array(elements):
            return elements.contains { element in element.mentions(atOrAbove: position) }

        case let .record(record):
            return record.fields.contains { field in field.mentions(atOrAbove: position) }

        // The inner slot is the closure's own frame, so only the outer one is
        // this frame's.
        case let .closure(_, captures):
            return captures.contains { outer, _ in outer >= position }

        case let .apply(callee, arguments):
            return callee.mentions(atOrAbove: position)
                || arguments.contains { _, argument in argument.mentions(atOrAbove: position) }

        case let .cast(read, _, _):
            return read.mentions(atOrAbove: position)

        case let .block(body):
            return body.mentions(atOrAbove: position)

        case let .conditional(condition, then: then, else: otherwise):
            return condition.mentions(atOrAbove: position)
                || then.contains { instruction in instruction.mentions(atOrAbove: position) }
                || otherwise?.contains { instruction in instruction.mentions(atOrAbove: position) } == true

        case let .loop(while: condition, body: body, round: round, keeps: keeps):
            return condition.mentions(atOrAbove: position)
                || body.mentions(atOrAbove: position)
                || round >= position
                || (keeps.map { kept in kept.upperBound > position } ?? false)

        case let .attempt(body, rescue: rescue, failure: failure):
            return body.mentions(atOrAbove: position)
                || rescue.mentions(atOrAbove: position)
                || failure >= position

        case let .call(call):
            return call.receiver?.mentions(atOrAbove: position) == true
                || call.arguments.contains { argument in argument?.mentions(atOrAbove: position) == true }
                || call.handed.contains { handed in handed.address.mentions(atOrAbove: position) }

        case let .dispatch(dispatch):
            return dispatch.receiver.mentions(atOrAbove: position)
                || dispatch.arguments.contains { _, argument in argument.mentions(atOrAbove: position) }
                || dispatch.calls.contains { _, call in
                    Operation.call(call).mentions(atOrAbove: position)
                }

        case let .leave(_, _, read):
            return read?.mentions(atOrAbove: position) == true
        }
    }
}

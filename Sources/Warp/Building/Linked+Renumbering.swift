//
//  Linked+Renumbering.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

extension Linked {
    // MARK: - Public
    // One row with every lowered type its body stands on answered again. The
    // only: what a row's slots and answer lower to is its signature read
    // against a table, which is the link's reading and not a number the
    // document gave. That holds for a native, which has no body at all, and
    // for a written one.
    func renumbered(_ answer: (LoweredType) throws -> LoweredType) rethrows -> Linked {
        guard case let .body(body, frame) = implementation else { return self }

        return Linked(
            self,
            implementation: .body(try Self.renumbered(body, answer), frame),
            sends: sends
        )
    }

    // MARK: - Private
    private static func renumbered(
        _ body: Body,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                try Self.renumbered(instruction, answer)
            },
            result: try body.result.map { result in try Self.renumbered(result, answer) }
        )
    }

    private static func renumbered(
        _ instruction: Instruction,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Instruction {
        Instruction(
            binding: try Self.renumbered(instruction.binding, answer),
            code: try Self.renumbered(instruction.code, answer),
            label: instruction.label
        )
    }

    private static func renumbered(
        _ binding: Instruction.Binding?,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Instruction.Binding? {
        switch binding {
        case let .bind(slot, settling)?:
            return .bind(slot, settling: try settling.map { type in try answer(type) })

        case let .declare(slot, settling)?:
            return .declare(slot, settling: try settling.map { type in try answer(type) })

        case let .assign(address, settling)?:
            return .assign(address, settling: try settling.map { type in try answer(type) })

        case nil:
            return nil
        }
    }

    private static func renumbered(
        _ operation: Operation,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Operation {
        switch operation {
        case .literal, .local:
            return operation

        case let .array(elements):
            return .array(try elements.map { element in try Self.renumbered(element, answer) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try Self.renumbered(field, answer) }
                )
            )

        // A closure stands as a row of its own, which this walk reaches on its
        // own turn. What is written here is the number that reaches it, and a
        // number carries no type.
        case .closure:
            return operation

        case let .apply(callee, arguments):
            return .apply(
                try Self.renumbered(callee, answer),
                arguments: try arguments.map { name, argument in
                    (name, try Self.renumbered(argument, answer))
                }
            )

        case let .cast(value, type, optional):
            return .cast(
                try Self.renumbered(value, answer),
                as: try answer(type),
                optional: optional
            )

        case let .block(body):
            return .block(try Self.renumbered(body, answer))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try Self.renumbered(condition, answer),
                then: try then.map { instruction in try Self.renumbered(instruction, answer) },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try Self.renumbered(instruction, answer) }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try Self.renumbered(condition, answer),
                body: try Self.renumbered(body, answer),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try Self.renumbered(body, answer),
                rescue: try Self.renumbered(rescue, answer),
                failure: failure
            )

        case let .call(call):
            return .call(try Self.renumbered(call, answer))

        // The calls a dispatch picks from are the link's to fill, so there is
        // nothing here for a document to number.
        case let .dispatch(dispatch):
            return .dispatch(
                DispatchOperation(
                    contract: dispatch.contract,
                    procedure: dispatch.procedure,
                    receiver: try Self.renumbered(dispatch.receiver, answer),
                    arguments: try dispatch.arguments.mapValues { argument in
                        try Self.renumbered(argument, answer)
                    },
                    calls: dispatch.calls
                )
            )

        case let .leave(reach, target, value):
            return .leave(
                reach,
                target: target,
                try value.map { value in try Self.renumbered(value, answer) }
            )
        }
    }

    private static func renumbered(
        _ call: CallOperation,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> CallOperation {
        CallOperation(
            procedure: call.procedure,
            receiver: try call.receiver.map { receiver in try Self.renumbered(receiver, answer) },
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try Self.renumbered(operation, answer) }
            },
            handed: call.handed
        )
    }

    private static func renumbered(
        _ argument: Argument,
        _ answer: (LoweredType) throws -> LoweredType
    ) rethrows -> Argument {
        switch argument {
        case let .value(operation):
            return .value(try Self.renumbered(operation, answer))

        case .reference:
            return argument
        }
    }
}

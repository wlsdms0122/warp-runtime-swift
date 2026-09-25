//
//  Operation+Rewriting.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Operation {
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
}

//
//  Linker+Relocating.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Which rows answer a contract's word, written into the calls that go through
// it.
//
// Not relocation. A call names its callee and compiling settles it; a call
// through a contract names no callee at all, and which types answer one is a
// fact of the world the documents were linked as. A type declared in a
// document the caller never names can answer a contract the caller calls
// through, so this is the one hole a document could not have filled itself.
struct Relocating {
    // MARK: - Property
    // The rows as compiling left them. Read for what a callee takes, which
    // filling does not change.
    private let table: [Linked]

    private let rows: [Name: Int]
    private let contractWords: [Name: ContractWord]
    private let shapes: ShapeTable

    // MARK: - Initializer
    init(table: [Linked], rows: [Name: Int], contractWords: [Name: ContractWord], shapes: ShapeTable) {
        self.table = table
        self.rows = rows
        self.contractWords = contractWords
        self.shapes = shapes
    }

    // MARK: - Public
    // Every row, with the calls through a contract filled in. A row holding no
    // such call comes back as it stands.
    func filled() throws -> [Linked] {
        try table.map { row in try filled(row) }
    }

    // MARK: - Private
    private func filled(_ row: Linked) throws -> Linked {
        guard case let .body(body, frame) = row.implementation else { return row }

        let place = Place.procedure(row.label.spelling, in: .assembled)
        let rewritten = try filled(body, at: place)

        return Linked(
            label: row.label,
            origin: row.origin,
            signature: row.signature,
            purity: row.purity,
            isolation: row.isolation,
            failing: row.failing,
            implementation: .body(rewritten, frame),
            sends: row.sends,
            in: row.table
        )
    }

    private func filled(_ body: Body, at place: Place) throws -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                Instruction(
                    binding: instruction.binding,
                    code: try filled(instruction.code, at: place),
                    label: instruction.label
                )
            },
            result: try body.result.map { result in try filled(result, at: place) }
        )
    }

    private func filled(_ operation: Operation, at place: Place) throws -> Operation {
        switch operation {
        case .literal, .local:
            return operation

        case let .array(elements):
            return .array(try elements.map { element in try filled(element, at: place) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try filled(field, at: place) }
                )
            )

        // A closure is a body of its own, and a call through a contract can be
        // written in one.
        case let .closure(linked, captures):
            return .closure(try filled(linked), captures: captures)

        case let .apply(callee, arguments):
            return .apply(
                try filled(callee, at: place),
                arguments: try arguments.map { name, argument in
                    (name, try filled(argument, at: place))
                }
            )

        case let .cast(value, shape, optional):
            return .cast(try filled(value, at: place), as: shape, optional: optional)

        case let .block(body):
            return .block(try filled(body, at: place))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try filled(condition, at: place),
                then: try then.map { instruction in
                    Instruction(
                        binding: instruction.binding,
                        code: try filled(instruction.code, at: place),
                        label: instruction.label
                    )
                },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in
                        Instruction(
                            binding: instruction.binding,
                            code: try filled(instruction.code, at: place),
                            label: instruction.label
                        )
                    }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try filled(condition, at: place),
                body: try filled(body, at: place),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try filled(body, at: place),
                rescue: try filled(rescue, at: place),
                failure: failure
            )

        case let .call(call):
            return .call(
                CallOperation(
                    procedure: call.procedure,
                    receiver: try call.receiver.map { receiver in try filled(receiver, at: place) },
                    arguments: try call.arguments.map { argument in
                        try argument.map { operation in try filled(operation, at: place) }
                    },
                    handed: call.handed
                )
            )

        case let .dispatch(dispatch):
            return .dispatch(try filled(dispatch, at: place))

        case let .leave(reach, target, value):
            return .leave(reach, target: target, try value.map { value in try filled(value, at: place) })
        }
    }

    private func filled(_ dispatch: DispatchOperation, at place: Place) throws -> DispatchOperation {
        let spelling = Name(normal: "\(dispatch.contract.spelling).\(dispatch.word.spelling)")

        guard let asked = contractWords[spelling] else {
            throw LinkError.unjudged("a call to '\(spelling)', which no contract declares", at: place)
        }

        let receiver = try filled(dispatch.receiver, at: place)
        let arguments = try dispatch.arguments.mapValues { argument -> Argument in
            guard case let .value(operation) = argument else { return argument }

            return .value(try filled(operation, at: place))
        }

        return DispatchOperation(
            contract: dispatch.contract,
            word: dispatch.word,
            receiver: receiver,
            arguments: arguments,
            calls: try asked.answering.reduce(into: [Name: CallOperation]()) { calls, entry in
                guard let row = rows[entry.value] else {
                    throw LinkError.unjudged(
                        "'\(entry.value)' answering '\(spelling)', which has no row",
                        at: place
                    )
                }

                calls[entry.key] = try CallOperation(
                    handing: arguments,
                    receiver: nil,
                    to: table[row],
                    row: row,
                    in: shapes,
                    at: place
                )
            }
        )
    }
}

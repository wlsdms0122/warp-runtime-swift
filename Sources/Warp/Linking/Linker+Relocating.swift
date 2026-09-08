//
//  Linker+Relocating.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What compiling a document left for the link, written into its bodies.
//
// Two different acts, one walk. A call carries the number its own document
// gave it, and the link answers with the row: that is renumbering, and what a
// document said is enough to do it. A call through a contract carries no
// callee at all, and which types answer one is a fact of the world the
// documents were linked as, since a type in a document the caller never names
// can answer a contract it calls through: that is filling, and no document
// could have done it.
//
// The two are done in one walk because each of them walks every body, and
// there is nothing the second needs that the first has not already read.
struct Relocating {
    // MARK: - Property
    // The rows as compiling left them. Read for what a callee takes, which
    // neither act changes.
    private let table: [Linked]

    private let rows: [Name: Int]
    private let words: [Name: Int]
    private let numbering: [Int: Numbering]
    private let contractWords: [Name: ContractWord]
    private let shapes: ShapeTable

    // MARK: - Initializer
    init(
        table: [Linked],
        rows: [Name: Int],
        words: [Name: Int],
        numbering: [Int: Numbering],
        contractWords: [Name: ContractWord],
        shapes: ShapeTable
    ) {
        self.table = table
        self.rows = rows
        self.words = words
        self.numbering = numbering
        self.contractWords = contractWords
        self.shapes = shapes
    }

    init(_ compiled: Compiled) {
        self.init(
            table: compiled.table,
            rows: compiled.rows,
            words: compiled.words,
            numbering: compiled.numbering,
            contractWords: compiled.contractWords,
            shapes: compiled.types.shapes
        )
    }

    // MARK: - Public
    // Every row, numbered by this link and with the calls through a contract
    // filled in.
    func linked() throws -> [Linked] {
        try table.map { row in try relocated(row) }
    }

    // MARK: - Private
    private func relocated(_ row: Linked) throws -> Linked {
        let place = Place.procedure(row.label.spelling, in: .assembled)
        let sends = try row.sends.map { number in try self.row(number, of: row.origin, at: place) }

        guard case let .body(body, frame) = row.implementation else {
            guard sends != row.sends else { return row }

            return Linked(row, implementation: row.implementation, sends: sends)
        }

        return Linked(
            row,
            implementation: .body(try filled(body, of: row.origin, at: place), frame),
            sends: sends
        )
    }

    // Which row of this link a document's number stands for.
    private func row(_ number: Int, of origin: Int, at place: Place) throws -> Int {
        guard let reference = numbering[origin]?.reference(at: number) else {
            throw LinkError.unjudged("a call standing at \(number), which its document never numbered", at: place)
        }

        switch reference {
        case let .sent(declared):
            guard let row = rows[declared] else {
                throw LinkError("'\(declared)' is called here, and no module in this link declares it", at: place)
            }

            return row

        case let .walked(spelling):
            guard let row = words[spelling] else {
                throw LinkError("'\(spelling)' is walked here, and no path in this link may reach it", at: place)
            }

            return row

        case let .row(row):
            return row
        }
    }

    private func filled(_ body: Body, of origin: Int, at place: Place) throws -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                Instruction(
                    binding: try relocated(instruction.binding, of: origin, at: place),
                    code: try filled(instruction.code, of: origin, at: place),
                    label: instruction.label
                )
            },
            result: try body.result.map { result in try filled(result, of: origin, at: place) }
        )
    }

    private func filled(_ operation: Operation, of origin: Int, at place: Place) throws -> Operation {
        switch operation {
        case .literal:
            return operation

        case let .local(address):
            return .local(try relocated(address, of: origin, at: place))

        case let .array(elements):
            return .array(try elements.map { element in try filled(element, of: origin, at: place) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try filled(field, of: origin, at: place) }
                )
            )

        // A closure is a body of its own, and a call through a contract can be
        // written in one.
        case let .closure(linked, captures):
            return .closure(try relocated(linked), captures: captures)

        case let .apply(callee, arguments):
            return .apply(
                try filled(callee, of: origin, at: place),
                arguments: try arguments.map { name, argument in
                    (name, try filled(argument, of: origin, at: place))
                }
            )

        case let .cast(value, shape, optional):
            return .cast(try filled(value, of: origin, at: place), as: shape, optional: optional)

        case let .block(body):
            return .block(try filled(body, of: origin, at: place))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try filled(condition, of: origin, at: place),
                then: try then.map { instruction in
                    Instruction(
                        binding: try relocated(instruction.binding, of: origin, at: place),
                        code: try filled(instruction.code, of: origin, at: place),
                        label: instruction.label
                    )
                },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in
                        Instruction(
                            binding: instruction.binding,
                            code: try filled(instruction.code, of: origin, at: place),
                            label: instruction.label
                        )
                    }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try filled(condition, of: origin, at: place),
                body: try filled(body, of: origin, at: place),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try filled(body, of: origin, at: place),
                rescue: try filled(rescue, of: origin, at: place),
                failure: failure
            )

        case let .call(call):
            return .call(try relocated(call, of: origin, at: place))

        case let .dispatch(dispatch):
            return .dispatch(try filled(dispatch, of: origin, at: place))

        case let .leave(reach, target, value):
            return .leave(reach, target: target, try value.map { value in try filled(value, of: origin, at: place) })
        }
    }

    // A named call with the row its document's number stands for, and its
    // operands walked.
    private func relocated(
        _ call: CallOperation,
        of origin: Int,
        at place: Place
    ) throws -> CallOperation {
        CallOperation(
            procedure: try row(call.procedure, of: origin, at: place),
            receiver: try call.receiver.map { receiver in try filled(receiver, of: origin, at: place) },
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try filled(operation, of: origin, at: place) }
            },
            handed: try call.handed.map { handed in
                CallOperation.Handed(
                    position: handed.position,
                    address: try relocated(handed.address, of: origin, at: place)
                )
            }
        )
    }

    // What a statement writes to, where writing to it walks a path.
    private func relocated(
        _ binding: Instruction.Binding?,
        of origin: Int,
        at place: Place
    ) throws -> Instruction.Binding? {
        guard case let .assign(address, settling)? = binding else { return binding }

        return .assign(try relocated(address, of: origin, at: place), settling: settling)
    }

    // A path with the rows its word steps stand for.
    private func relocated(_ address: Address, of origin: Int, at place: Place) throws -> Address {
        Address(
            slot: address.slot,
            steps: try address.steps.map { step in
                switch step {
                case let .word(number, spelling, optional):
                    return .word(try row(number, of: origin, at: place), spelling, optional: optional)

                case let .at(inner, optional):
                    return .at(try relocated(inner, of: origin, at: place), optional: optional)

                case .field, .key, .index:
                    return step
                }
            }
        )
    }

    private func filled(_ dispatch: DispatchOperation, of origin: Int, at place: Place) throws -> DispatchOperation {
        let spelling = Name(normal: "\(dispatch.contract.spelling).\(dispatch.word.spelling)")

        guard let asked = contractWords[spelling] else {
            throw LinkError.unjudged("a call to '\(spelling)', which no contract declares", at: place)
        }

        let receiver = try filled(dispatch.receiver, of: origin, at: place)
        let arguments = try dispatch.arguments.mapValues { argument -> Argument in
            switch argument {
            case let .value(operation):
                return .value(try filled(operation, of: origin, at: place))

            case let .reference(address):
                return .reference(try relocated(address, of: origin, at: place))
            }
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

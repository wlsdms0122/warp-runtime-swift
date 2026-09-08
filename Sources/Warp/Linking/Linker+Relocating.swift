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
        let label = row.label
        let sends = try row.sends.map { number in try self.row(number, of: row.origin, at: label) }

        guard case let .body(body, frame) = row.implementation else {
            guard sends != row.sends else { return row }

            return Linked(row, implementation: row.implementation, sends: sends)
        }

        return Linked(
            row,
            implementation: .body(try filled(body, of: row.origin, at: label), frame),
            sends: sends
        )
    }

    // Where a refusal about a row's code points. Built where one is raised
    // rather than for every row walked.
    private func place(of label: Name) -> Place {
        Place.procedure(label.spelling, in: .assembled)
    }

    // Which row of this link a document's number stands for. The reading is
    // the numbering's; what to say when the link has no such name is this.
    private func row(_ number: Int, of origin: Int, at label: Name) throws -> Int {
        guard let numbering = numbering[origin] else {
            throw LinkError.unjudged(
                "a call standing at \(number) in a document that numbered nothing",
                at: place(of: label)
            )
        }

        if let row = numbering.row(number, rows: rows, words: words) { return row }

        switch numbering.reference(at: number) {
        case let .sent(declared):
            throw LinkError(
                "'\(declared)' is called here, and no module in this link declares it",
                at: place(of: label)
            )

        case let .walked(spelling):
            throw LinkError(
                "'\(spelling)' is walked here, and no path in this link may reach it",
                at: place(of: label)
            )

        case .row, nil:
            throw LinkError.unjudged(
                "a call standing at \(number), which its document never numbered",
                at: place(of: label)
            )
        }
    }

    private func filled(_ body: Body, of origin: Int, at label: Name) throws -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                try relocated(instruction, of: origin, at: label)
            },
            result: try body.result.map { result in try filled(result, of: origin, at: label) }
        )
    }

    // One statement, both what it computes and where it writes. A statement
    // stands in three places (a body, and either arm of a conditional) and
    // reads the same way in all of them.
    private func relocated(_ instruction: Instruction, of origin: Int, at label: Name) throws -> Instruction {
        Instruction(
            binding: try relocated(instruction.binding, of: origin, at: label),
            code: try filled(instruction.code, of: origin, at: label),
            label: instruction.label
        )
    }

    private func filled(_ operation: Operation, of origin: Int, at label: Name) throws -> Operation {
        switch operation {
        case .literal:
            return operation

        case let .local(address):
            return .local(try relocated(address, of: origin, at: label))

        case let .array(elements):
            return .array(try elements.map { element in try filled(element, of: origin, at: label) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try filled(field, of: origin, at: label) }
                )
            )

        // A closure is a body of its own, and a call through a contract can be
        // written in one.
        case let .closure(linked, captures):
            return .closure(try relocated(linked), captures: captures)

        case let .apply(callee, arguments):
            return .apply(
                try filled(callee, of: origin, at: label),
                arguments: try arguments.map { name, argument in
                    (name, try filled(argument, of: origin, at: label))
                }
            )

        case let .cast(value, shape, optional):
            return .cast(try filled(value, of: origin, at: label), as: shape, optional: optional)

        case let .block(body):
            return .block(try filled(body, of: origin, at: label))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try filled(condition, of: origin, at: label),
                then: try then.map { instruction in
                    try relocated(instruction, of: origin, at: label)
                },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in
                        try relocated(instruction, of: origin, at: label)
                    }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try filled(condition, of: origin, at: label),
                body: try filled(body, of: origin, at: label),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try filled(body, of: origin, at: label),
                rescue: try filled(rescue, of: origin, at: label),
                failure: failure
            )

        case let .call(call):
            return .call(try relocated(call, of: origin, at: label))

        case let .dispatch(dispatch):
            return .dispatch(try filled(dispatch, of: origin, at: label))

        case let .leave(reach, target, value):
            return .leave(reach, target: target, try value.map { value in try filled(value, of: origin, at: label) })
        }
    }

    // A named call with the row its document's number stands for, and its
    // operands walked.
    private func relocated(
        _ call: CallOperation,
        of origin: Int,
        at label: Name
    ) throws -> CallOperation {
        CallOperation(
            procedure: try row(call.procedure, of: origin, at: label),
            receiver: try call.receiver.map { receiver in try filled(receiver, of: origin, at: label) },
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try filled(operation, of: origin, at: label) }
            },
            handed: try call.handed.map { handed in
                CallOperation.Handed(
                    position: handed.position,
                    address: try relocated(handed.address, of: origin, at: label)
                )
            }
        )
    }

    // What a statement writes to, where writing to it walks a path.
    private func relocated(
        _ binding: Instruction.Binding?,
        of origin: Int,
        at label: Name
    ) throws -> Instruction.Binding? {
        guard case let .assign(address, settling)? = binding else { return binding }

        return .assign(try relocated(address, of: origin, at: label), settling: settling)
    }

    // A path with the rows its word steps stand for.
    private func relocated(_ address: Address, of origin: Int, at label: Name) throws -> Address {
        Address(
            slot: address.slot,
            steps: try address.steps.map { step in
                switch step {
                case let .word(number, spelling, optional):
                    return .word(try row(number, of: origin, at: label), spelling, optional: optional)

                case let .at(inner, optional):
                    return .at(try relocated(inner, of: origin, at: label), optional: optional)

                case .field, .key, .index:
                    return step
                }
            }
        )
    }

    private func filled(_ dispatch: DispatchOperation, of origin: Int, at label: Name) throws -> DispatchOperation {
        let spelling = Name(normal: "\(dispatch.contract.spelling).\(dispatch.word.spelling)")

        guard let asked = contractWords[spelling] else {
            throw LinkError.unjudged("a call to '\(spelling)', which no contract declares", at: place(of: label))
        }

        let receiver = try filled(dispatch.receiver, of: origin, at: label)
        let arguments = try dispatch.arguments.mapValues { argument -> Argument in
            switch argument {
            case let .value(operation):
                return .value(try filled(operation, of: origin, at: label))

            case let .reference(address):
                return .reference(try relocated(address, of: origin, at: label))
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
                        at: place(of: label)
                    )
                }

                calls[entry.key] = try CallOperation(
                    handing: { name in arguments[name] },
                    written: arguments.keys,
                    receiver: nil,
                    to: table[row],
                    row: row,
                    in: shapes,
                    at: place(of: label)
                )
            }
        )
    }
}

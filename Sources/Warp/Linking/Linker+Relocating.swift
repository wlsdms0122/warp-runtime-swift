//
//  Linker+Relocating.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// A table something may run against, beside how the numbers its bodies carry
// are read.
//
// Running reads rows, and a lowered body carries its document's own numbers,
// so nothing may run against a table until something says which the numbers
// are. `Relocating` says it by writing every body over. Compiling says it
// beside the bodies instead, since it runs a few of them once and writing all
// of them over would cost more than the running.
struct Answered: Sendable {
    // MARK: - Property
    let table: [Linked]
    let rows: [Name: Int]
    let words: [Name: Int]

    private let numbers: Numbers

    // MARK: - Initializer
    private init(table: [Linked], rows: [Name: Int], words: [Name: Int], numbers: Numbers) {
        self.table = table
        self.rows = rows
        self.words = words
        self.numbers = numbers
    }

    // A table holding nothing a link could answer: rows built from native
    // words alone, which carry no lowered body and send nothing.
    static func unanswerable(_ table: [Linked], rows: [Name: Int], words: [Name: Int]) -> Answered {
        Answered(table: table, rows: rows, words: words, numbers: .rows)
    }

    // A table as compiling left it, and where each document numbers from. The
    // bodies keep the numbers they were lowered with, so what reads one is
    // told which document it came from.
    //
    // Which row each of those numbers stands for is worked out here, once per
    // number rather than once per body standing on one. A name this link has
    // no row for stands as nothing rather than as a refusal: a document
    // numbers every bare spelling its paths step to, and a step onto a field
    // reaches no declaration.
    static func documents(
        _ table: [Linked],
        rows: [Name: Int],
        words: [Name: Int],
        numbering: [Int: Numbering]
    ) -> Answered {
        let views = numbering.mapValues { held in
            held.answers(rows: rows, words: words).map { answer -> Int? in
                guard case let .row(row) = answer else { return nil }

                return row
            }
        }

        return Answered(
            table: table,
            rows: rows,
            words: words,
            numbers: .documents(numbering, views: views)
        )
    }

    // Made by `Relocating` alone, which is what keeps a table nobody answered
    // from standing as one whose numbers are rows.
    fileprivate static func relocated(_ table: [Linked], rows: [Name: Int], words: [Name: Int]) -> Answered {
        Answered(table: table, rows: rows, words: words, numbers: .rows)
    }

    // MARK: - Public
    // How a run reads the numbers the bodies carry.
    var resolving: Resolving {
        switch numbers {
        case .rows:
            return .rows

        case let .documents(_, views):
            return .documents(views)
        }
    }

    // How an expression folded beside a document's bodies is numbered, so that
    // what is lowered now and what was lowered before stand in one numbering.
    // Nothing where the document numbered nothing.
    func numbering(of origin: Int) -> Numbering? {
        switch numbers {
        case .rows:
            return Numbering(rows: rows, words: words)

        case let .documents(numbering, _):
            return numbering[origin]
        }
    }

    // MARK: - Private
    private enum Numbers: Sendable {
        // This link's own rows.
        case rows

        // Each document's own, with where its numbers came from and which row
        // each of them stands for.
        case documents([Int: Numbering], views: [Int: [Int?]])
    }
}

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

    // What each document's shape numbers turned out to be in this link.
    //
    // Answered once per number rather than at every shape met: a name is read
    // as many times as a document numbered one, and not as many times as its
    // bodies stand on it. A document that lowered no body numbered no shape
    // and has no entry here.
    private let shapeRows: [Int: (types: [ShapeNumbering.Answer], memberships: [ShapeNumbering.Answer])]

    private let contractWords: [Name: ContractWord]
    private let shapes: ShapeTable

    // MARK: - Initializer
    init(
        table: [Linked],
        rows: [Name: Int],
        words: [Name: Int],
        numbering: [Int: Numbering],
        shapeNumbering: [Int: ShapeNumbering],
        contractWords: [Name: ContractWord],
        shapes: ShapeTable
    ) {
        self.table = table
        self.rows = rows
        self.words = words
        self.numbering = numbering
        self.shapeRows = shapeNumbering.mapValues { held in
            (
                types: held.types.indices.map { number in held.type(number, in: shapes) },
                memberships: held.memberships.indices.map { number in
                    held.membership(number, in: shapes)
                }
            )
        }
        self.contractWords = contractWords
        self.shapes = shapes
    }

    init(_ compiled: Compiled) {
        self.init(
            table: compiled.table,
            rows: compiled.rows,
            words: compiled.words,
            numbering: compiled.numbering,
            shapeNumbering: compiled.shapeNumbering,
            contractWords: compiled.contractWords,
            shapes: compiled.types.shapes
        )
    }

    // MARK: - Public
    // Every row, numbered by this link and with the calls through a contract
    // filled in.
    func linked() throws -> Answered {
        Answered.relocated(
            try table.map { row in try relocated(row) },
            rows: rows,
            words: words
        )
    }

    // MARK: - Private
    // Where the walk is: which document wrote this row, what a refusal calls
    // it, and this link's answers to the shape numbers that document gave.
    // Read once on entering a row rather than at every shape inside it.
    private struct Standing {
        let origin: Int
        let label: Name
        let shapes: (types: [ShapeNumbering.Answer], memberships: [ShapeNumbering.Answer])?
    }

    private func relocated(_ row: Linked) throws -> Linked {
        let standing = Standing(origin: row.origin, label: row.label, shapes: shapeRows[row.origin])
        let sends = try row.sends.map { number in try self.row(number, in: standing) }

        guard case let .body(body, frame) = row.implementation else {
            guard sends != row.sends else { return row }

            return Linked(row, implementation: row.implementation, sends: sends)
        }

        return Linked(
            row,
            implementation: .body(try filled(body, in: standing), frame),
            sends: sends
        )
    }

    // Where a refusal about a row's code points. Built where one is raised
    // rather than for every row walked.
    private func place(of label: Name) -> Place {
        Place.procedure(label.spelling, in: .assembled)
    }

    // Which row of this link a document's number stands for. The reading is
    // the numbering's; what to say when it does not answer is this.
    private func row(_ number: Int, in standing: Standing) throws -> Int {
        guard let numbering = numbering[standing.origin] else {
            throw LinkError.unjudged(
                "a call standing at \(number) in a document that numbered nothing",
                at: place(of: standing.label)
            )
        }

        switch numbering.row(number, rows: rows, words: words) {
        case let .row(row):
            return row

        case let .unfound(.sent(declared)):
            throw LinkError(
                "'\(declared)' is called here, and no module in this link declares it",
                at: place(of: standing.label)
            )

        case let .unfound(.walked(spelling)):
            throw LinkError(
                "'\(spelling)' is walked here, and no path in this link may reach it",
                at: place(of: standing.label)
            )

        case .unnumbered:
            throw LinkError.unjudged(
                "a call standing at \(number), which its document never numbered",
                at: place(of: standing.label)
            )
        }
    }

    private func filled(_ body: Body, in standing: Standing) throws -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                try relocated(instruction, in: standing)
            },
            result: try body.result.map { result in try filled(result, in: standing) }
        )
    }

    // One statement, both what it computes and where it writes. A statement
    // stands in three places (a body, and either arm of a conditional) and
    // reads the same way in all of them.
    private func relocated(_ instruction: Instruction, in standing: Standing) throws -> Instruction {
        Instruction(
            binding: try relocated(instruction.binding, in: standing),
            code: try filled(instruction.code, in: standing),
            label: instruction.label
        )
    }

    private func filled(_ operation: Operation, in standing: Standing) throws -> Operation {
        switch operation {
        case .literal:
            return operation

        case let .local(address):
            return .local(try relocated(address, in: standing))

        case let .array(elements):
            return .array(try elements.map { element in try filled(element, in: standing) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try filled(field, in: standing) }
                )
            )

        // A closure is a body of its own, and a call through a contract can be
        // written in one.
        case let .closure(linked, captures):
            return .closure(try relocated(linked), captures: captures)

        case let .apply(callee, arguments):
            return .apply(
                try filled(callee, in: standing),
                arguments: try arguments.map { name, argument in
                    (name, try filled(argument, in: standing))
                }
            )

        case let .cast(value, shape, optional):
            return .cast(
                try filled(value, in: standing),
                as: try relocated(shape, in: standing),
                optional: optional
            )

        case let .block(body):
            return .block(try filled(body, in: standing))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try filled(condition, in: standing),
                then: try then.map { instruction in
                    try relocated(instruction, in: standing)
                },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in
                        try relocated(instruction, in: standing)
                    }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try filled(condition, in: standing),
                body: try filled(body, in: standing),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try filled(body, in: standing),
                rescue: try filled(rescue, in: standing),
                failure: failure
            )

        case let .call(call):
            return .call(try relocated(call, in: standing))

        case let .dispatch(dispatch):
            return .dispatch(try filled(dispatch, in: standing))

        case let .leave(reach, target, value):
            return .leave(reach, target: target, try value.map { value in try filled(value, in: standing) })
        }
    }

    // A named call with the row its document's number stands for, and its
    // operands walked.
    private func relocated(
        _ call: CallOperation,
        in standing: Standing
    ) throws -> CallOperation {
        CallOperation(
            procedure: try row(call.procedure, in: standing),
            receiver: try call.receiver.map { receiver in try filled(receiver, in: standing) },
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try filled(operation, in: standing) }
            },
            handed: try call.handed.map { handed in
                CallOperation.Handed(
                    position: handed.position,
                    address: try relocated(handed.address, in: standing)
                )
            }
        )
    }

    // What a statement writes to and the shape it takes it as: the path where
    // writing to it walks one, and the row of every shape either way.
    private func relocated(
        _ binding: Instruction.Binding?,
        in standing: Standing
    ) throws -> Instruction.Binding? {
        switch binding {
        case let .bind(slot, settling)?:
            return .bind(slot, settling: try relocated(settling, in: standing))

        case let .declare(slot, settling)?:
            return .declare(slot, settling: try relocated(settling, in: standing))

        case let .assign(address, settling)?:
            return .assign(
                try relocated(address, in: standing),
                settling: try relocated(settling, in: standing)
            )

        case nil:
            return nil
        }
    }

    // A shape with the rows its document's numbers stand for.
    private func relocated(_ shape: Shape?, in standing: Standing) throws -> Shape? {
        try shape.map { held in try relocated(held, in: standing) }
    }

    private func relocated(_ shape: Shape, in standing: Standing) throws -> Shape {
        guard let answers = standing.shapes else {
            throw LinkError.unjudged(
                "a shape in a document that numbered none",
                at: place(of: standing.label)
            )
        }

        return try shape.renumbered(
            type: { number in try row(answers.types, at: number, calling: "named", in: standing) },
            membership: { number in
                try row(answers.memberships, at: number, calling: "bounding a parameter", in: standing)
            }
        )
    }

    // Which row a document's shape number turned out to be. The reading is
    // the numbering's; what to say when it does not answer is this.
    private func row(
        _ answers: [ShapeNumbering.Answer],
        at number: Int,
        calling what: String,
        in standing: Standing
    ) throws -> Int {
        guard answers.indices.contains(number) else {
            throw LinkError.unjudged(
                "a shape standing at \(number), which its document never numbered",
                at: place(of: standing.label)
            )
        }

        switch answers[number] {
        case let .row(row):
            return row

        case let .unfound(name):
            throw LinkError(
                "'\(name)' is \(what) here, and no module in this link declares it",
                at: place(of: standing.label)
            )

        case .unnumbered:
            throw LinkError.unjudged(
                "a shape standing at \(number), which its document never numbered",
                at: place(of: standing.label)
            )
        }
    }

    // A path with the rows its word steps stand for.
    private func relocated(_ address: Address, in standing: Standing) throws -> Address {
        Address(
            slot: address.slot,
            steps: try address.steps.map { step in
                switch step {
                case let .word(number, spelling, optional):
                    return .word(try row(number, in: standing), spelling, optional: optional)

                case let .at(inner, optional):
                    return .at(try relocated(inner, in: standing), optional: optional)

                case .field, .key, .index:
                    return step
                }
            }
        )
    }

    private func filled(_ dispatch: DispatchOperation, in standing: Standing) throws -> DispatchOperation {
        let spelling = Name(normal: "\(dispatch.contract.spelling).\(dispatch.word.spelling)")

        guard let asked = contractWords[spelling] else {
            throw LinkError.unjudged("a call to '\(spelling)', which no contract declares", at: place(of: standing.label))
        }

        let receiver = try filled(dispatch.receiver, in: standing)
        let arguments = try dispatch.arguments.mapValues { argument -> Argument in
            switch argument {
            case let .value(operation):
                return .value(try filled(operation, in: standing))

            case let .reference(address):
                return .reference(try relocated(address, in: standing))
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
                        at: place(of: standing.label)
                    )
                }

                calls[entry.key] = try CallOperation(
                    handing: { name in arguments[name] },
                    written: arguments.keys,
                    receiver: nil,
                    to: table[row],
                    row: row,
                    in: shapes,
                    at: place(of: standing.label)
                )
            }
        )
    }
}

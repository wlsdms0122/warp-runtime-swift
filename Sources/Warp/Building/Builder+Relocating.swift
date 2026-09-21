//
//  Builder+Relocating.swift
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

    // What a closure a run over these rows makes is spelled with, by origin.
    let naming: [Closure.Document]

    private let numbers: Numbers

    // MARK: - Initializer
    private init(table: [Linked], rows: [Name: Int], naming: [Closure.Document], numbers: Numbers) {
        self.table = table
        self.rows = rows
        self.naming = naming
        self.numbers = numbers
    }

    // A table holding nothing a link could answer: rows built from native
    // procedures alone, which carry no lowered body and send nothing.
    static func unanswerable(_ table: [Linked], rows: [Name: Int], naming: [Closure.Document]) -> Answered {
        Answered(table: table, rows: rows, naming: naming, numbers: .rows)
    }

    // A table as compiling left it, and where each document numbers from. The
    // bodies keep the numbers they were lowered with, so what reads one is
    // told which document it came from, and `named` says which row each of
    // those numbers stands for.
    static func documents(
        _ table: [Linked],
        rows: [Name: Int],
        naming: [Closure.Document],
        numbering: [Int: Numbering],
        named: [Int: [Int?]],
        closures: [Int: [Int]]
    ) -> Answered {
        Answered(
            table: table,
            rows: rows,
            naming: naming,
            numbers: .documents(numbering, named: named, closures: closures)
        )
    }

    // Which row each of one document's numbers stands for, worked out once per
    // number rather than once per body standing on one.
    static func answering(_ numbering: Numbering, rows: [Name: Int]) -> [Int?] {
        numbering.answers(rows: rows).map { answer -> Int? in
            guard case let .row(row) = answer else { return nil }

            return row
        }
    }

    // A table every number of which was made to stand here. The same value as
    // one nothing numbered, said under the name that says who may make it:
    // `Relocating` alone, which is what keeps a table nobody answered from
    // standing as one whose numbers are rows.
    fileprivate static func relocated(_ table: [Linked], rows: [Name: Int], naming: [Closure.Document]) -> Answered {
        unanswerable(table, rows: rows, naming: naming)
    }

    // MARK: - Public
    // The same answer over a table lowered since, with the closure rows that
    // lowering took. What a name stands for is the documents' and this link's,
    // and neither moved while the bodies were lowered; the closures are the
    // rows those bodies just made, so only they are handed again.
    func holding(_ table: [Linked], closures: [Int: [Int]]) -> Answered {
        switch numbers {
        case .rows:
            return Answered(table: table, rows: rows, naming: naming, numbers: numbers)

        case let .documents(numbering, named, _):
            return Answered(
                table: table,
                rows: rows,
                naming: naming,
                numbers: .documents(numbering, named: named, closures: closures)
            )
        }
    }

    // How a run reads the numbers the bodies carry.
    var resolving: Resolving {
        switch numbers {
        case .rows:
            return .rows

        case let .documents(numbering, named, closures):
            return .documents(
                named.reduce(into: [Int: [Int?]]()) { views, entry in
                    // A closure the link has no row for yet stands as nothing,
                    // the same as a name it has no row for. Constants fold
                    // before any body is lowered, so at that point every one of
                    // them is nothing, and nothing there can reach one.
                    let held = closures[entry.key] ?? []
                    let counted = numbering[entry.key]?.closureCount ?? held.count

                    views[entry.key] = entry.value + (0..<counted).map { written in
                        held.indices.contains(written) ? held[written] : nil
                    }
                }
            )
        }
    }

    // How an expression folded beside a document's bodies is numbered, so that
    // what is lowered now and what was lowered before stand in one numbering.
    // Nothing where the document numbered nothing.
    func numbering(of origin: Int) -> Numbering? {
        switch numbers {
        case .rows:
            return Numbering(rows: rows)

        case let .documents(numbering, _, _):
            return numbering[origin]
        }
    }

    // MARK: - Private
    private enum Numbers: Sendable {
        // This link's own rows.
        case rows

        // Each document's own, with where its numbers came from and which row
        // each of them stands for. The names and the closures stand apart
        // because they settle at different times: a name's row is the link's
        // before anything is lowered, and a closure's row is made by lowering.
        case documents([Int: Numbering], named: [Int: [Int?]], closures: [Int: [Int]])
    }
}

// What compiling a document left for the link, written into its bodies.
//
// Two different acts, one walk. A call carries the number its own document
// gave it, and the link answers with the row: that is renumbering, and what a
// document said is enough to do it. A call through a contract carries no
// callee at all, and which types answer one is a fact of the graph the
// documents were linked as, since a type in a document the caller never names
// can answer a contract it calls through: that is filling, and no document
// could have done it.
//
// The two are done in one walk because each of them walks every body, and
// there is nothing the second needs that the first has not already read.
final class Relocating {
    // MARK: - Property
    // The rows of this link, every one of them standing before the first body
    // is walked.
    private let table: [Linked]

    private let rows: [Name: Int]
    private let numbering: [Numbering]

    // What each document's type numbers turned out to be in this link.
    //
    // Answered once per number rather than at every type met: a name is read
    // as many times as a document numbered one, and not as many times as its
    // bodies stand on it. A document that lowered no body numbered no type
    // and has no entry here.
    private let typeRows: [LoweredTypeNumbering.Rows]

    private let contractProcedures: [Name: ContractProcedure]
    private let loweredTypes: LoweredTypeTable

    // Which row each document's closures took. A closure is reached by a
    // number and by nothing else, so this answers where the two name tables
    // answer a spelling.
    private let closures: [[Int]]

    private let spelled: ClosureRows

    // Every row relocated once, whichever asks for it first: the table, or a
    // value holding a closure whose row it is. One object per row, so a
    // closure a value holds holds the row of the table it stands in. Made
    // with this link's reading of a row, which is why it waits for self.
    private lazy var answering = ClosureAnswering(
        spelled: spelled,
        table: table,
        documents: documents,
        rewriting: { [unowned self] row in try self.relocated(row) }
    )

    private let documents: [Place.Document]
    private let naming: [Closure.Document]

    // MARK: - Initializer
    init(
        table: [Linked],
        rows: [Name: Int],
        spelled: ClosureRows,
        documents: [Place.Document],
        naming: [Closure.Document],
        numbering: [Numbering],
        typeNumbering: [LoweredTypeNumbering],
        contractProcedures: [Name: ContractProcedure],
        closures: [[Int]],
        loweredTypes: LoweredTypeTable
    ) {
        self.closures = closures
        self.table = table
        self.spelled = spelled
        self.rows = rows
        self.documents = documents
        self.naming = naming
        self.numbering = numbering
        self.typeRows = typeNumbering.map { held in held.rows(in: loweredTypes) }
        self.contractProcedures = contractProcedures
        self.loweredTypes = loweredTypes
    }

    // What compiling left, read as this link's rows. Filling a call through a
    // contract reads the row the link found answering it, over the parameters
    // that row takes, so every row is made to stand here rather than as the
    // walk reaches it.
    convenience init(_ assembled: Assembled, types: TypeTable, supplied: Supplying) throws {
        let loweredTypes = types.loweredTypes

        self.init(
            table: try assembled.table.map { row in
                try row.judged.linked(
                    in: loweredTypes,
                    of: row.origin,
                    nth: row.nth,
                    supplied: supplied,
                    at: assembled.documents[row.origin]
                )
            },
            rows: assembled.rows,
            spelled: assembled.spelled,
            documents: assembled.documents,
            naming: assembled.naming,
            numbering: assembled.numbering,
            typeNumbering: assembled.typeNumbering,
            contractProcedures: ContractProcedure.table(in: types),
            closures: assembled.closures,
            loweredTypes: loweredTypes
        )
    }

    // MARK: - Public
    // Every row, numbered by this link and with the calls through a contract
    // filled in.
    func linked() throws -> Answered {
        Answered.relocated(try table.indices.map(relocated(at:)), rows: rows, naming: naming)
    }

    // What each document's variables start a run holding, read as this link's
    // rows. A starting value was folded before anything was relocated, the way
    // a literal in a body was.
    func started(_ variables: [[(name: Name, value: Value)]]) throws -> [[(name: Name, value: Value)]] {
        try variables.enumerated().map { origin, held in
            try held.map { name, value in
                (
                    name,
                    try relocated(
                        value,
                        in: Standing(
                            origin: origin,
                            place: .variable(name.spelling, in: documents[origin]),
                            loweredTypes: typeRows[origin]
                        )
                    )
                )
            }
        }
    }

    // MARK: - Private
    // Where the walk is: which document wrote this row, what a refusal calls
    // it, and this link's answers to the type numbers that document gave.
    // Read once on entering a row rather than at every type inside it.
    private struct Standing {
        let origin: Int

        // Where a refusal about what is being walked points. Read once on
        // entering rather than built at every refusal that never happens.
        let place: Place

        let loweredTypes: LoweredTypeNumbering.Rows
    }

    // A folded value read as this link's rows. A closure was made by running a
    // closure literal before anything was relocated, so it holds the number
    // its document gave and a body standing in the tables the fold read. Both
    // are answered here the way a call's number is.
    //
    // The body is relocated where it is met rather than read out of a table of
    // finished rows: the rows are being made in this same walk, and a row
    // holding a closure of another is the reason a value carries one at all.
    private func relocated(_ value: Value, in standing: Standing) throws -> Value {
        guard value.holdsProcedure else { return value }

        return try value.rewritten { closure in
            try answering.answered(closure, at: standing.place)
        }
    }

    // A row relocated once.
    private func relocated(at row: Int) throws -> Linked {
        try answering.row(at: row)
    }

    private func relocated(_ row: Linked) throws -> Linked {
        let standing = Standing(
            origin: row.origin,
            place: .procedure(row.label.spelling, in: documents[row.origin]),
            loweredTypes: typeRows[row.origin]
        )
        let sends = try row.sends.map { sent in
            let reached = try self.row(sent.row, in: standing)

            // A procedure a caller brought has no body a compile could read,
            // so what it sends is held here, where its sends first meet rows.
            guard table[reached].access.reachesOtherDocuments || table[reached].origin == row.origin else {
                throw BuildError(
                    "'\(row.label)' sends '\(table[reached].label)', which is private to the"
                        + " document that declares it",
                    at: standing.place
                )
            }

            return sent.reaching(reached)
        }

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

    // Which row of this link a document's number stands for. The reading is
    // the numbering's; what to say when it does not answer is this.
    private func row(_ number: Int, in standing: Standing) throws -> Int {
        switch numbering[standing.origin].row(
            number,
            rows: rows,
            closures: closures[standing.origin]
        ) {
        case let .row(row):
            return row

        case let .unfound(.sent(declared)):
            throw BuildError(
                "'\(declared)' is called here, and no module in this link declares it",
                at: standing.place
            )

        case let .unfound(.closure(written)):
            throw BuildError.unjudged(
                "closure \(written) of this document, which the build lowered no row for",
                at: standing.place
            )

        case .unnumbered:
            throw BuildError.unjudged(
                "a call standing at \(number), which its document never numbered",
                at: standing.place
            )
        }
    }

    // The closures its literal values hold are the door's to answer; the
    // numbers are this link's.
    private func filled(_ body: Body, in standing: Standing) throws -> Body {
        try answering.answered(
            body,
            at: standing.place,
            operation: { operation in try relocated(operation, in: standing) },
            type: { type in try standing.loweredTypes.read(type, at: standing.place) }
        )
    }

    // One operation with the rows its document's numbers stand for, handed
    // over with what nests in it already relocated.
    private func relocated(_ operation: Operation, in standing: Standing) throws -> Operation {
        switch operation {
        // A closure is a body of its own, and a call through a contract can be
        // written in one.
        case let .closure(number, captures):
            return .closure(try row(number, in: standing), captures: captures)

        case let .call(call):
            return .call(try relocated(call, in: standing))

        case let .dispatch(dispatch):
            return .dispatch(try relocated(dispatch, in: standing))

        case .literal, .local, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
            return operation
        }
    }

    // A named call with the row its document's number stands for.
    private func relocated(
        _ call: CallOperation,
        in standing: Standing
    ) throws -> CallOperation {
        let procedure = try row(call.procedure, in: standing)

        // What a call hands over fills the slots the row it reaches declares.
        // The row is this link's answer and is known here, so the question is
        // asked once rather than at every call the run makes of it.
        //
        // What is left after a document has judged its own calls: a call
        // reaching a row some other document holds. Which row that is, is this
        // link's answer, so this is the one that can ask, and it says which
        // call it is about the way the refusals beside it do.
        guard call.arguments.count == table[procedure].slots.count else {
            throw BuildError(
                "a call stands \(call.arguments.count) argument(s) where the"
                    + " \(table[procedure].slots.count) its callee declares stand",
                at: standing.place
            )
        }

        return CallOperation(
            procedure: procedure,
            receiver: call.receiver,
            arguments: call.arguments,
            handed: call.handed
        )
    }

    // A call through a contract with the calls the rows answering it stand
    // for, one per type that answers.
    private func relocated(_ dispatch: DispatchOperation, in standing: Standing) throws -> DispatchOperation {
        let spelling = ContractProcedure.spelling(
            of: dispatch.contract,
            procedure: dispatch.procedure
        )

        guard let asked = contractProcedures[spelling] else {
            throw BuildError.unjudged("a call to '\(spelling)', which no contract declares", at: standing.place)
        }

        return DispatchOperation(
            contract: dispatch.contract,
            procedure: dispatch.procedure,
            receiver: dispatch.receiver,
            arguments: dispatch.arguments,
            calls: try asked.answering.reduce(into: [Name: CallOperation]()) { calls, entry in
                guard let row = rows[entry.value] else {
                    throw BuildError.unjudged(
                        "'\(entry.value)' answering '\(spelling)', which has no row",
                        at: standing.place
                    )
                }

                calls[entry.key] = try CallOperation(
                    handing: { name in dispatch.arguments[name] },
                    written: dispatch.arguments.keys,
                    receiver: nil,
                    to: table[row],
                    row: row,
                    in: loweredTypes,
                    at: standing.place
                )
            }
        )
    }
}

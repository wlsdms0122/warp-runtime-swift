//
//  Relocating.swift
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
// callee at all, and which types answer one is a fact of the graph the
// documents were linked as, since a type in a document the caller never names
// can answer a contract it calls through: that is filling, and no document
// could have done it.
//
// The two are done in one walk because each of them walks every body, and
// there is nothing the second needs that the first has not already read.
final class Relocating {
    // Where the walk is: which document wrote this row, what a refusal calls
    // it, and this link's answers to the type numbers that document gave.
    // Read once on entering a row rather than at every type inside it.
    private struct Context {
        // MARK: - Property
        let origin: Int

        // Where a refusal about what is being walked points. Read once on
        // entering rather than built at every refusal that never happens.
        let place: Place

        let typeRows: LoweredTypeNumbering.Renumbering

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The rows of this link, every one of them standing before the first body
    // is walked.
    private let table: [Linked]

    private let rows: [Name: Int]
    private let numbering: [Numbering]

    // Each document's own declarations by row, and the spellings only private
    // declarations wear, read when a lookup fails to say why.
    private let owned: [[Name: Int]]
    private let concealed: Set<Name>

    // What each document's type numbers turned out to be in this link.
    //
    // Resolved once per number rather than at every type met: a name is read
    // as many times as a document numbered one, and not as many times as its
    // bodies stand on it. A document that lowered no body numbered no type
    // and has no entry here.
    private let typeRows: [LoweredTypeNumbering.Renumbering]

    private let contractProcedures: [Name: LoweredContractProcedure]
    private let loweredTypes: LoweredTypeTable

    // Which row each document's closures took. A closure is reached by a
    // number and by nothing else, so this answers where the two name tables
    // answer a spelling.
    private let closures: [[Int]]

    private let spelled: ClosureRowTable

    // Every row relocated once, whichever asks for it first: the table, or a
    // value holding a closure whose row it is. One object per row, so a
    // closure a value holds holds the row of the table it stands in. Made
    // with this link's reading of a row, which is why it waits for self.
    private lazy var resolver = ClosureResolver(
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
        spelled: ClosureRowTable,
        documents: [Place.Document],
        naming: [Closure.Document],
        numbering: [Numbering],
        owned: [[Name: Int]],
        concealed: Set<Name>,
        typeNumbering: [LoweredTypeNumbering],
        contractProcedures: [Name: LoweredContractProcedure],
        closures: [[Int]],
        loweredTypes: LoweredTypeTable
    ) {
        self.closures = closures
        self.owned = owned
        self.concealed = concealed
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
    // walk reaches it. `contractProcedures` are the procedures the contracts
    // of `types` ask, read off it where the satisfaction was written into it.
    convenience init(
        _ assembled: Assembled,
        types: TypeTable,
        contractProcedures: [Name: LoweredContractProcedure],
        supplied: Supplying
    ) throws {
        let loweredTypes = types.loweredTypes

        self.init(
            table: try assembled.table.map { row in
                try row.judged.linked(
                    in: loweredTypes,
                    of: row.origin,
                    closure: row.closure,
                    numbering: assembled.numbering[row.origin],
                    supplied: supplied,
                    at: assembled.documents[row.origin]
                )
            },
            rows: assembled.rows,
            spelled: assembled.spelled,
            documents: assembled.documents,
            naming: assembled.naming,
            numbering: assembled.numbering,
            owned: assembled.owned,
            concealed: assembled.concealed,
            typeNumbering: assembled.typeNumbering,
            contractProcedures: contractProcedures,
            closures: assembled.closures,
            loweredTypes: loweredTypes
        )
    }

    // MARK: - Public
    // Every row, numbered by this link and with the calls through a contract
    // filled in.
    func linked() throws -> ResolvedTable {
        ResolvedTable.relocated(try table.indices.map(relocated(at:)), rows: rows, naming: naming)
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
                        in: Context(
                            origin: origin,
                            place: .variable(name.spelling, in: documents[origin]),
                            typeRows: typeRows[origin]
                        )
                    )
                )
            }
        }
    }

    // MARK: - Private
    // A folded value read as this link's rows. A closure was made by running a
    // closure literal before anything was relocated, so it holds the number
    // its document gave and a body standing in the tables the fold read. Both
    // are answered here the way a call's number is.
    //
    // The body is relocated where it is met rather than read out of a table of
    // finished rows: the rows are being made in this same walk, and a row
    // holding a closure of another is the reason a value carries one at all.
    private func relocated(_ value: Value, in context: Context) throws -> Value {
        guard value.holdsProcedure else { return value }

        return try value.rewritten { closure in try resolver.resolved(closure, at: context.place) }
    }

    // A row relocated once.
    private func relocated(at row: Int) throws -> Linked {
        try resolver.row(at: row)
    }

    private func relocated(_ row: Linked) throws -> Linked {
        let context = Context(
            origin: row.origin,
            place: .procedure(row.label.spelling, in: documents[row.origin]),
            typeRows: typeRows[row.origin]
        )

        switch row.implementation {
        case let .body(body, frame):
            return Linked(row, implementation: .body(try filled(body, in: context), frame))

        case let .native(native, sends):
            let reached = try sends.map { sent in sent.reaching(try self.row(sent.row, in: context)) }

            guard reached != sends else { return row }

            return Linked(row, implementation: .native(native, sends: reached))
        }
    }

    // Which row of this link a document's number stands for. The reading is
    // the numbering's; what to say when it does not answer is this.
    private func row(_ number: Int, in context: Context) throws -> Int {
        switch numbering[context.origin].row(
            number,
            rows: rows,
            own: owned[context.origin],
            closures: closures[context.origin]
        ) {
        case let .row(row):
            return row

        // A spelling only a private declaration wears is one this document
        // cannot name: a call from another document and a native's declared
        // send alike meet it here.
        case let .unfound(.sent(declared)) where concealed.contains(declared):
            throw BuildError.concealed(declared, at: context.place)

        case let .unfound(.sent(declared)):
            throw BuildError(
                "'\(declared)' is called here, and no module in this link declares it",
                at: context.place
            )

        case let .unfound(.closure(written)):
            throw BuildError.unjudged(
                "closure \(written) of this document, which the build lowered no row for",
                at: context.place
            )

        case .unnumbered:
            throw BuildError.unjudged(
                "a call standing at \(number), which its document never numbered",
                at: context.place
            )
        }
    }

    // The closures its literal values hold are the door's to answer; the
    // numbers are this link's.
    private func filled(_ body: LoweredBody, in context: Context) throws -> LoweredBody {
        try resolver.resolved(
            body,
            at: context.place,
            operation: { operation in try relocated(operation, in: context) },
            type: { type in try context.typeRows.read(type, at: context.place) }
        )
    }

    // One operation with the rows its document's numbers stand for, handed
    // over with what nests in it already relocated.
    private func relocated(_ operation: Operation, in context: Context) throws -> Operation {
        switch operation {
        // A closure is a body of its own, and a call through a contract can be
        // written in one.
        case let .closure(number, captures):
            return .closure(try row(number, in: context), captures: captures)

        case let .call(call):
            return .call(try relocated(call, in: context))

        case let .dispatch(dispatch):
            return .dispatch(try relocated(dispatch, in: context))

        case .literal, .local, .array, .record, .apply, .cast, .block, .conditional, .loop, .attempt, .leave:
            return operation
        }
    }

    // A named call with the row its document's number stands for.
    private func relocated(
        _ call: CallOperation,
        in context: Context
    ) throws -> CallOperation {
        let procedure = try row(call.procedure, in: context)

        // What a call hands over fills the slots the row it reaches declares.
        // The row is this link's answer and is known here, so every call is
        // counted once, here, rather than at every call the run makes of it.
        guard call.arguments.count == table[procedure].slots.count else {
            throw BuildError(
                "a call stands \(call.arguments.count) argument(s) where the"
                    + " \(table[procedure].slots.count) its callee declares stand",
                at: context.place
            )
        }

        return CallOperation(
            procedure: procedure,
            arguments: call.arguments,
            handed: call.handed
        )
    }

    // A call through a contract with the calls the rows answering it stand
    // for, one per type that answers.
    private func relocated(_ dispatch: DispatchOperation, in context: Context) throws -> DispatchOperation {
        let spelling = ContractProcedure.spelling(
            of: dispatch.contract,
            procedure: dispatch.procedure
        )

        guard let asked = contractProcedures[spelling] else {
            throw BuildError.unjudged("a call to '\(spelling)', which no contract declares", at: context.place)
        }

        return DispatchOperation(
            contract: dispatch.contract,
            procedure: dispatch.procedure,
            first: dispatch.first,
            arguments: dispatch.arguments,
            calls: try asked.answering.reduce(into: [Name: CallOperation]()) { calls, entry in
                guard let row = rows[entry.value] else {
                    throw BuildError.unjudged(
                        "'\(entry.value)' answering '\(spelling)', which has no row",
                        at: context.place
                    )
                }

                calls[entry.key] = try CallOperation(
                    handing: [nil] + dispatch.arguments.map { argument in Optional(argument) },
                    to: table[row],
                    row: row,
                    picked: true,
                    in: loweredTypes,
                    at: context.place
                )
            }
        )
    }
}

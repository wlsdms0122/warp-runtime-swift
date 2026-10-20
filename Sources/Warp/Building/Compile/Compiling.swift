//
//  Compiling.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

// What the documents already compiled proved, which is what the next one is
// compiled against.
//
// A document is compiled against the two things it asks of what stands
// before it: a declaration's signature, which says everything a call may
// expect, and a body it can run while folding a constant. Both are here, and
// a document reaches nothing else outside itself.
//
// It grows as each document is laid down, and the growing is the whole reason
// it is one value rather than a dozen. A table handed to a second holder is
// copied whole the next time it is written to, so the tables a compile grows
// are held here and read from here.
struct Compiling {
    // MARK: - Property
    // The types of the list, answering with the claims the document being
    // laid down stands on, and the procedures the contracts ask.
    private(set) var types: TypeTable
    let contractProcedures: [Name: LoweredContractProcedure]

    // Which document each position is, for a refusal that names one.
    let documents: [Place.Document]

    // What a closure each document writes is spelled with.
    let naming: [Closure.Document]

    // The rows, and where every number a body carries stands.
    var lowering: Lowering

    // Every judgement the compile asks and every row it builds reads the table
    // the run will read.
    var loweredTypes: LoweredTypeTable { types.loweredTypes }

    // The rows folding runs against, held apart from the lowering: a row is
    // written in when the phase that lowered it ends, so what a body folds
    // through is what stood lowered before its phase began rather than
    // whatever the row order reached first. Lowering is then the only holder
    // of its own table, and writing a row into it copies nothing.
    private var foldingRows: [Linked] = []
    private var loweredRows: [Int] = []

    // What a compile laying more documents beside these takes from them.
    var carried: Carried {
        Carried(
            table: lowering.table,
            rows: lowering.rows,
            concealed: lowering.concealed,
            documents: lowering.documents
        )
    }

    // MARK: - Initializer
    // Nothing laid down yet, beside the private spellings of every document
    // about to be laid down.
    init(
        concealing concealed: Set<Name>,
        types: TypeTable,
        contractProcedures: [Name: LoweredContractProcedure],
        naming documents: [Place.Document],
        spelling naming: [Closure.Document]
    ) {
        self.types = types
        self.contractProcedures = contractProcedures
        self.documents = documents
        self.naming = naming
        self.lowering = Lowering(
            concealing: concealed,
            contractProcedures: contractProcedures,
            loweredTypes: types.loweredTypes
        )
    }

    // The documents already laid down, read against the table this compile is
    // asking with, beside the private spellings of every document the compile
    // lays down after them.
    //
    // Nothing here is worked out again. `Carried` is what those documents
    // left and holds nothing read against a table, so the only thing this
    // compile brings is the table itself: its rows carry what it has worked
    // out and what it is still owed.
    init(
        _ carried: Carried,
        concealing concealed: Set<Name>,
        types: TypeTable,
        contractProcedures: [Name: LoweredContractProcedure],
        naming documents: [Place.Document],
        spelling naming: [Closure.Document]
    ) {
        self.types = types
        self.contractProcedures = contractProcedures
        self.documents = documents
        self.naming = naming
        self.lowering = Lowering(
            carried,
            concealing: concealed,
            contractProcedures: contractProcedures,
            loweredTypes: types.loweredTypes
        )

        // Every body laid down is lowered already, so all of them are
        // something the next document may fold through.
        self.foldingRows = lowering.table.map(\.folding)
    }

    // MARK: - Public
    // The document laid down next asks with the claims it stands on. The
    // rows are the same rows: only what answers a contract changes.
    mutating func answer(with types: TypeTable) {
        self.types = types
        self.lowering.answer(with: types.loweredTypes)
    }

    // One document already compiled laid down, as the document itself wrote
    // it.
    //
    // Its rows are cut by where the document says its declarations stand,
    // which is the one place that boundary is drawn.
    mutating func lay(_ document: Compiled, at origin: Int, rows: [Linked]) {
        let held = lowering.hold(
            standing: Array(rows[document.standing]),
            closures: Array(rows[document.lifted]),
            numbering: document.numbering,
            variables: document.variables.map(\.name)
        )

        assert(held.origin == origin, "a document is laid at the origin it is held at")
    }

    // The same for every document laid down, said once they all stand. This
    // reads the rows whole and the documents arrive in the order the host
    // handed them over, so one of them may import a procedure another laid after it
    // declares.
    //
    // A number none of them reaches is a document laid without what it sends,
    // which is refused here rather than left to read as a number with no row
    // where a body of it is run.
    mutating func resolveEvery() throws {
        for origin in documents.indices {
            lowering.resolve(origin)
            try lowering.refuseMiscountedCalls(of: origin, at: documents[origin])

            for (number, row) in (lowering.documents[origin].named ?? []).enumerated() where row == nil {
                guard case let .unfound(.sent(declared)) = lowering.documents[origin].numbering.row(
                    number,
                    rows: lowering.rows,
                    own: lowering.own(origin),
                    closures: []
                ) else {
                    continue
                }

                // A contract's procedure has no row: a call to it is a dispatch
                // the link answers through the contract, so a document sending
                // one is missing nothing.
                guard contractProcedures[declared] == nil else { continue }

                guard lowering.concealed.contains(declared) else {
                    throw BuildError(
                        "'\(declared)' is sent by this document, and no document laid"
                            + " beside it declares one",
                        at: Place(in: documents[origin])
                    )
                }

                throw BuildError.concealed(declared, at: Place(in: documents[origin]))
            }
        }
    }

    // A body lowered into its row. Noted as well as written, because what
    // folding runs is a table of its own and this is what is copied into it.
    mutating func lower(_ row: Int, body block: Block, judgements: JudgementTable, at place: Place) throws {
        try lowering.lower(row, body: block, judgements: judgements, at: place)

        loweredRows.append(row)
    }

    // The rows a fold reads while the procedures themselves are lowered: the
    // stand-ins the compiler holds there until each lowers.
    func folding() -> ResolvedTable {
        ResolvedTable.documents(
            foldingRows,
            rows: lowering.rows,
            naming: naming,
            documents: lowering.documents
        )
    }

    // Every closure a laid document's values hold resolved to the row it
    // stands at here, through the door the link resolves them by. A document
    // read out of an object holds its closures by spelling alone, and one
    // compiled in memory holds them standing as the rows of the compile that
    // folded them, which is not this one; a fold through either hands them
    // on, so every one is resolved here before anything folds. The numbers
    // their code carries read against this table as they are.
    mutating func resolveHeldClosures() throws {
        let resolver = ClosureResolver(
            spelled: ClosureRowTable(
                naming: naming,
                numbering: lowering.documents.map(\.numbering),
                closures: lowering.documents.map(\.closureRows),
                documents: documents
            ),
            table: lowering.table,
            documents: documents
        )

        lowering.replace(table: try lowering.table.indices.map { row in try resolver.row(at: row) })
    }

    // What has been lowered since the last phase, written in.
    mutating func foldable() {
        foldingRows.append(contentsOf: lowering.table[foldingRows.count...].map(\.folding))

        for row in loweredRows {
            foldingRows[row] = lowering.table[row].folding
        }

        loweredRows.removeAll(keepingCapacity: true)
    }

    // One document's reading. A context is made for the document whose body
    // is being read, since the declarations it may name are its own by its
    // block, private ones included, and every other document's by the
    // spelling the link holds.
    func context(of origin: Int) -> TypingContext {
        context(owning: lowering.own(origin))
    }

    // The same for a document whose rows are not held yet: what the documents
    // behind it declare, and nothing of its own.
    func context() -> TypingContext {
        context(owning: [:])
    }

    // MARK: - Private
    private func context(owning own: [Name: Int]) -> TypingContext {
        TypingContext(
            types: types,
            linked: lowering.table,
            rows: lowering.rows,
            own: own,
            concealed: lowering.concealed,
            contractProcedures: contractProcedures
        )
    }
}

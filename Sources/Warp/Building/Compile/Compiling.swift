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
// A document is compiled against the seven things it asks of what stands
// before it: what a declaration takes and answers, whether it is const,
// isolated and failing, what the build read off a body that declared no
// answer, and a body it can run while folding a constant. All seven are here,
// and a document reaches nothing else outside itself.
//
// It grows as each document is laid down, and the growing is the whole reason
// it is one value rather than a dozen. A table handed to a second holder is
// copied whole the next time it is written to, so the tables a compile grows
// are held here and read from here.
struct Compiling {
    // MARK: - Property
    // What only the whole list answers, which a document has no say in.
    let types: TypeTable
    let contractProcedures: [Name: LoweredContractProcedure]

    // Which document each position is, for a refusal that names one.
    let documents: [Place.Document]

    // What a closure each document writes is spelled with.
    let naming: [Closure.Document]

    // What the build read off a body whose declaration wrote no `returns`.
    // Only those: what a declaration wrote is on its row already, and a table
    // holding every spelling would hash every declared name to say what the
    // row says.
    var answers: [Int: LoweredType] = [:]

    // The rows, and where every number a body carries stands.
    var lowering: Lowering

    // Every judgment the compile asks and every row it builds reads the table
    // the run will read.
    var loweredTypes: LoweredTypeTable { types.loweredTypes }

    // Which row each document's numbers stand for, answered when the document
    // is laid down.
    private var named: [Int: [Int?]] = [:]

    // The rows folding runs against, held apart from the lowering: a row is
    // written in when the phase that lowered it ends, so what a body folds
    // through is what stood settled before its phase began rather than
    // whatever the row order reached first. Lowering is then the only holder
    // of its own table, and writing a row into it copies nothing.
    private var foldingRows: [Linked] = []
    private var loweredRows: [Int] = []

    // What a compile laying more documents beside these takes from them.
    var carried: Carried {
        Carried(
            table: lowering.table,
            rows: lowering.rows,
            owned: lowering.owned,
            concealed: lowering.concealed,
            named: named,
            numbering: lowering.numbering,
            closureRows: lowering.closureRows,
            variables: lowering.variables,
            answers: answers
        )
    }

    // MARK: - Initializer
    // Nothing laid down yet.
    init(
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
            contractProcedures: contractProcedures,
            loweredTypes: types.loweredTypes
        )
    }

    // The documents already laid down, read against the table this compile is
    // asking with.
    //
    // Nothing here is worked out again. `Carried` is what those documents
    // left and holds nothing read against a table, so the only thing this
    // compile brings is the table itself: its rows carry what it has worked
    // out and what it is still owed.
    init(
        _ carried: Carried,
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
            contractProcedures: contractProcedures,
            loweredTypes: types.loweredTypes
        )
        self.answers = carried.answers
        self.named = carried.named

        // Every body laid down is lowered already, so all of them are
        // something the next document may fold through.
        self.foldingRows = lowering.table.map(\.folding)
    }

    // MARK: - Public
    // One document already compiled laid down, as the document itself wrote
    // it.
    //
    // Its rows and what it settled are cut by where the document says its
    // declarations stand, which is the one place that boundary is drawn.
    //
    // What it proved about its own bodies and what the build read off one that
    // declared no answer are read off what it settled rather than off the rows
    // it stands as. A row is a declaration lowered against a link's types,
    // and none of those is a type.
    mutating func lay(
        _ document: Compiled,
        at origin: Int,
        rows: [Linked],
        answering read: [Name: LoweredType]
    ) {
        hold(
            origin,
            standing: Array(rows[document.standing]),
            closures: Array(rows[document.lifted]),
            numbering: document.numbering,
            variables: document.variables.map(\.name)
        )

        // What the build read off a body stands by the row it was read off.
        let own = lowering.own(origin)

        for (name, answer) in read {
            guard let row = own[name] else { continue }

            answers[row] = answer
        }
    }

    // One document laid down: its declarations take the rows after the ones
    // already here, and its numbering says what the bodies it lowers are
    // written with. Which rows those are is answered here rather than looked
    // up again, since laying them down is what decided it.
    @discardableResult
    mutating func hold(
        _ origin: Int,
        standing block: [Linked],
        closures lifted: [Linked] = [],
        numbering: Numbering,
        variables ordered: [Name]
    ) -> Range<Int> {
        lowering.hold(
            origin,
            standing: block,
            closures: lifted,
            numbering: numbering,
            variables: ordered
        )
    }

    // Which row each number this document gave stands for. A number of its own
    // reaches a name it declared or one behind it, so the answer never moves
    // after this.
    mutating func answering(_ origin: Int) {
        named[origin] = Answered.answering(
            lowering.numbering[origin] ?? Numbering(sends: [], declared: []),
            rows: lowering.rows,
            own: lowering.own(origin)
        )
    }

    // The same for every document laid down, said once they all stand. This
    // reads the rows whole and the documents arrive in the order the caller
    // handed them over, so one of them may import a procedure another laid after it
    // declares.
    //
    // A number none of them reaches is a document laid without what it sends,
    // which is refused here rather than left to read as a number with no row
    // where a body of it is run.
    mutating func answering() throws {
        for origin in documents.indices {
            answering(origin)

            for (number, row) in (named[origin] ?? []).enumerated() where row == nil {
                guard case let .unfound(.sent(declared)) = lowering.numbering[origin]?.row(
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

    // A type the build read off a body rather than out of a signature, held to
    // the document that wrote the body: the rows it stands on are numbered
    // beside the ones that document's bodies stand on.
    // A body's answer stands by its row, which this document holds by now.
    mutating func read(_ answer: LoweredType, as declared: Name, of origin: Int) {
        if let row = lowering.own(origin)[declared] {
            answers[row] = answer
        }

        lowering.stands(on: answer, of: origin)
    }

    // The row a selector names from this document: its own declaration first,
    // then what the link holds under the spelling. What the build derived of
    // a declaration stands on the row, so this is where a fact is read.
    func declared(_ selector: Name, from origin: Int) -> Linked? {
        (lowering.own(origin)[selector] ?? lowering.rows[selector]).map { row in lowering.table[row] }
    }

    // A body lowered into its row. Noted as well as written, because what
    // folding runs is a table of its own and this is what is copied into it.
    mutating func settle(
        _ row: Int,
        body block: Block,
        constants: [Name: (value: Value, type: LoweredType)],
        at place: Place
    ) throws {
        try lowering.settle(row, body: block, constants: constants, at: place)

        loweredRows.append(row)
    }

    // The stand-ins, while the procedures themselves settle: a procedure folding through
    // a procedure would be a cycle, and which procedures are already lowered is a fact
    // of name order rather than of the text.
    func folding() -> Answered {
        Answered.documents(
            foldingRows,
            rows: lowering.rows,
            naming: naming,
            numbering: lowering.numbering,
            named: named,
            closures: lowering.closureRows
        )
    }

    // Every closure a laid document's values hold answered with the row it
    // stands at here, through the door the link answers them by. A document
    // read out of an object holds its closures by spelling alone, and one
    // compiled in memory holds them standing as the rows of the compile that
    // folded them, which is not this one; a fold through either hands them
    // on, so every one is answered here before anything folds. The numbers
    // their code carries read against this table as they are.
    mutating func answerHeld() throws {
        let numbering = try naming.indices.map { origin -> Numbering in
            guard let held = lowering.numbering[origin] else {
                throw BuildError.unjudged("a document laid down without its numbering", at: Place(in: documents[origin]))
            }

            return held
        }
        let answering = ClosureAnswering(
            spelled: ClosureRows(
                naming: naming,
                numbering: numbering,
                closures: naming.indices.map { origin in lowering.closureRows[origin] ?? [] },
                documents: documents
            ),
            table: lowering.table,
            documents: documents
        )

        lowering.replace(table: try lowering.table.indices.map { row in try answering.row(at: row) })
    }

    // What has been lowered since the last phase, written in.
    mutating func foldable() {
        foldingRows.append(contentsOf: lowering.table[foldingRows.count...].map(\.folding))

        for row in loweredRows {
            foldingRows[row] = lowering.table[row].folding
        }

        loweredRows.removeAll(keepingCapacity: true)
    }

    // One document's reading. Which names hold boxes is the document's own, so
    // a context is made for the document whose body is being read, and so are
    // the declarations it may name: its own by its block, private ones
    // included, and every other document's by the spelling the link holds.
    func context(reading variables: Set<Name>, of origin: Int) -> TypingContext {
        TypingContext(
            types: types,
            linked: lowering.table,
            rows: lowering.rows,
            own: lowering.own(origin),
            answers: answers,
            contractProcedures: contractProcedures,
            variables: variables
        )
    }

    // MARK: - Private
}

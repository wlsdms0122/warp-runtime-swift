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
// before it: what a declaration takes and answers, whether it is pure,
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
    let contractWords: [Name: ContractWord]

    // Which document each position is, for a refusal that names one.
    let documents: [Place.Document]

    // The facts nobody declared, over every declaration laid down so far.
    var pure: Set<Name> = []
    var isolated: Set<Name> = []
    var failing: [Name: Failing] = [:]

    // What the build read off a body whose declaration wrote no `returns`.
    // Only those: what a declaration wrote is on its row already, and a table
    // holding every spelling would hash every declared name to say what the
    // row says.
    var answers: [Name: Shape] = [:]

    // The rows, and where every number a body carries stands.
    var lowering: Lowering

    // Every judgment the compile asks and every row it builds reads the table
    // the run will read.
    var shapes: ShapeTable { types.shapes }

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

    // MARK: - Initializer
    // Nothing laid down yet.
    init(
        types: TypeTable,
        contractWords: [Name: ContractWord],
        naming documents: [Place.Document]
    ) {
        self.types = types
        self.contractWords = contractWords
        self.documents = documents
        self.lowering = Lowering(
            contractWords: contractWords,
            shapes: types.shapes
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
        contractWords: [Name: ContractWord],
        naming documents: [Place.Document]
    ) {
        self.types = types
        self.contractWords = contractWords
        self.documents = documents
        self.lowering = Lowering(
            carried,
            contractWords: contractWords,
            shapes: types.shapes
        )
        self.pure = carried.pure
        self.isolated = carried.isolated
        self.failing = carried.failing
        self.answers = carried.answers
        self.named = carried.named

        // Every body laid down is lowered already, so all of them are
        // something the next document may fold through.
        self.foldingRows = lowering.table
    }

    // MARK: - Public
    // What a compile laying more documents beside these takes from them.
    var carried: Carried {
        Carried(
            table: lowering.table,
            rows: lowering.rows,
            named: named,
            numbering: lowering.numbering,
            closureRows: lowering.closureRows,
            variables: lowering.variables,
            pure: pure,
            isolated: isolated,
            failing: failing,
            answers: answers
        )
    }

    // One document already compiled laid down, as the document itself wrote
    // it.
    //
    // Its rows and what it settled are cut by where the document says its
    // declarations stand, which is the one place that boundary is drawn.
    //
    // What it proved about its own bodies and what the build read off one that
    // declared no answer are read off what it settled rather than off the rows
    // it stands as. A row is a declaration lowered against a link's shapes,
    // and none of those is a shape.
    mutating func lay(
        _ document: Compiled,
        at origin: Int,
        rows: [Linked],
        answering read: [Name: Shape]
    ) {
        hold(
            origin,
            standing: Array(rows[document.standing]),
            closures: Array(rows[document.lifted]),
            numbering: document.numbering,
            variables: document.variables.map(\.name)
        )

        for judged in document.table[document.standing] {
            if judged.purity == .pure { pure.insert(judged.label) }
            if judged.isolation == .isolated { isolated.insert(judged.label) }

            failing[judged.label] = judged.failing
        }

        answers.merge(read) { _, answer in answer }
    }

    // One document laid down: its declarations take the rows after the ones
    // already here, and its numbering says what the bodies it lowers are
    // written with.
    mutating func hold(
        _ origin: Int,
        standing block: [Linked],
        closures lifted: [Linked] = [],
        numbering: Numbering,
        variables ordered: [Name]
    ) {
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
            lowering.numbering[origin] ?? Numbering(imports: [], declared: []),
            rows: lowering.rows
        )
    }

    // The same for every document laid down, said once they all stand. This
    // reads the rows whole and the documents arrive in the order the caller
    // handed them over, so one of them may import a word another laid after it
    // declares.
    mutating func answering() {
        for origin in documents.indices { answering(origin) }
    }

    // A shape the build read off a body rather than out of a signature, held to
    // the document that wrote the body: the rows it stands on are numbered
    // beside the ones that document's bodies stand on.
    mutating func read(_ answer: Shape, as declared: Name, of origin: Int) {
        answers[declared] = answer

        lowering.stands(on: answer, of: origin)
    }

    // A body lowered into its row. Noted as well as written, because what
    // folding runs is a table of its own and this is what is copied into it.
    mutating func settle(_ row: Int, body block: Block, at place: Place) throws {
        try lowering.settle(row, body: block, at: place)

        loweredRows.append(row)
    }

    // The stand-ins, while the words themselves settle: a word folding through
    // a word would be a circle, and which words are already lowered is a fact
    // of name order rather than of the text.
    func folding() -> Answered {
        Answered.documents(
            foldingRows,
            rows: lowering.rows,
            numbering: lowering.numbering,
            named: named,
            closures: lowering.closureRows
        )
    }

    // What has been lowered since the last phase, written in.
    mutating func foldable() {
        foldingRows.append(contentsOf: lowering.table[foldingRows.count...])

        for row in loweredRows {
            foldingRows[row] = lowering.table[row]
        }

        loweredRows.removeAll(keepingCapacity: true)
    }

    // One document's reading. Which names hold boxes is the document's own, so
    // a frame is made for the document whose body is being read.
    func frame(reading variables: Set<Name>) -> TypeFrame {
        TypeFrame(
            types: types,
            linked: lowering.table,
            rows: lowering.rows,
            answers: answers,
            pure: pure,
            isolated: isolated,
            failing: failing,
            contractWords: contractWords,
            variables: variables
        )
    }

    // MARK: - Private
}

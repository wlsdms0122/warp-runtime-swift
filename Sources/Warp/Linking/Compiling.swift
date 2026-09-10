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
// isolated and failing, what the link read off a body that declared no
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
    let answering: Set<Name>

    // Which document each position is, for a refusal that names one.
    let documents: [Place.Document]

    // The facts nobody declared, over every declaration laid down so far.
    var pure: Set<Name> = []
    var isolated: Set<Name> = []
    var failing: [Name: Failing] = [:]

    // What the link read off a body whose declaration wrote no `returns`.
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
    init(_ gathered: Gathered, naming documents: [Place.Document]) {
        self.init(
            types: gathered.types,
            contractWords: gathered.contractWords,
            answering: gathered.answering,
            naming: documents
        )
    }

    private init(
        types: TypeTable,
        contractWords: [Name: ContractWord],
        answering: Set<Name>,
        naming documents: [Place.Document]
    ) {
        self.types = types
        self.contractWords = contractWords
        self.answering = answering
        self.documents = documents
        self.lowering = Lowering(
            documents: documents.count,
            contractWords: contractWords,
            shapes: types.shapes
        )
    }

    // What a caller already had compiled, laid down the way the walk lays a
    // document it just compiled. A document arriving here says nothing about
    // how it was made, so what the two ways build is one accumulator.
    //
    // The rows keep the numbers their documents gave their calls, which is
    // what `named` answers, and their shapes are read as this link's rows:
    // folding runs these bodies, and running reads a shape where it stands.
    init(
        _ compiled: [Compiled],
        types: TypeTable,
        contractWords: [Name: ContractWord],
        answering: Set<Name>,
        naming documents: [Place.Document]
    ) throws {
        self.init(
            types: types,
            contractWords: contractWords,
            answering: answering,
            naming: documents
        )

        for (origin, document) in compiled.enumerated() {
            let standing = document.shapeNumbering.rows(in: types.shapes)
            let rows = try document.table.map { judged -> Linked in
                let row = judged.lowered(in: types.shapes, of: origin)

                return try row.shaped { shape in
                    try standing.read(shape, at: .procedure(row.label.spelling, in: document.document))
                }
            }

            hold(
                origin,
                standing: Array(rows.prefix(document.declared.count)),
                closures: Array(rows.dropFirst(document.declared.count)),
                numbering: document.numbering,
                variables: document.variables.map(\.name)
            )

            for row in rows.prefix(document.declared.count) {
                if row.purity == .pure { pure.insert(row.label) }
                if row.isolation == .isolated { isolated.insert(row.label) }

                failing[row.label] = row.failing
            }

            for (declared, answer) in document.answers {
                answers[declared] = try standing.read(
                    answer,
                    at: .procedure(declared.spelling, in: document.document)
                )
            }
        }

        // Said after every block stands, since a path steps to a declaration
        // of another document as readily as to one of its own.
        for (origin, document) in compiled.enumerated() {
            steps(origin, to: document.words.compactMapValues { declared in lowering.rows[declared] })
        }

        // Every body handed over is lowered already, so all of them are
        // something the next document may fold through.
        foldable()
    }

    // MARK: - Public
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

    // Which row each bare spelling this document's paths step to reaches, and
    // what each number of its own reaches with it. A number of its own reaches
    // a name it declared or one behind it, so the answer never moves after
    // this.
    mutating func steps(_ origin: Int, to reached: [Name: Int]) {
        lowering.stepping(origin, to: reached)

        named[origin] = Answered.answering(
            lowering.numbering[origin] ?? Numbering(imports: [], walks: [], declared: []),
            rows: lowering.rows,
            words: lowering.words[origin]
        )
    }

    // A shape the link read off a body rather than out of a signature, held to
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
            words: lowering.words,
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

    // One document's reading. What a path may walk to is the document's own,
    // so a frame is made for the document whose body is being read.
    func frame(
        stepping words: [Name: Name],
        reading variables: Set<Name>,
        writing requiring: Requiring
    ) -> TypeFrame {
        TypeFrame(
            types: types,
            linked: lowering.table,
            rows: lowering.rows,
            answers: answers,
            words: words,
            pure: pure,
            isolated: isolated,
            failing: failing,
            contractWords: contractWords,
            variables: variables,
            requiring: requiring
        )
    }

    // MARK: - Private
}

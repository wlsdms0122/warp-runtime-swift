//
//  Compiled.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// One document compiled, in its own coordinates.
//
// The rows are this document's alone and numbered from zero: its declarations
// in name order, then the closures its bodies lifted, in the order the
// document numbers them. Where the block lands in a link is the link's answer,
// so nothing here says it.
//
// Which declaration a run starts from is not here either, so an entry names
// nothing in this and one document compiled once answers every entry asked
// of it.
public struct Compiled: Sendable, Declaring {
    // Which document this is, so a refusal a build makes about it says
    // where the procedures are.
    let document: Place.Document

    // What it declares in the three type tables, as it wrote them. A
    // link lays these down in the order it was handed the documents to
    // make the table its rows are numbered against, and reads no type of
    // this document anywhere else.
    let types: [Name: TypeExpression]
    let constraints: [Name: [TypeExpression]]
    let contracts: [Name: [Name: Signature]]

    // Which contracts it said each type answers, as it wrote them. The link
    // holds the claim to the declarations behind it, and which declarations
    // those are is a fact of the link rather than of this document.
    let claims: [Name: Set<Name>]

    // The pairs its bodies lean on: a type handed where a contract is asked.
    // Unresolved here, the way a procedure this document sends and does not declare
    // is unresolved. Which types answer a contract is read off the claims of
    // the whole list, and a claim may be written in a document this one never
    // names.
    let leaned: [Claim: Place]

    // The declared spellings, in the order their rows stand. A row past
    // the end of this is a closure, which no spelling reaches.
    let declared: [Name]

    let table: [Judged]

    // Where this document's declarations stand among its rows, and where the
    // closures its bodies lifted stand behind them. Every list of this
    // document's rows is cut by these, so nothing cuts them apart, and a list
    // of some other length traps where it is read.
    var standing: Range<Int> { 0 ..< declared.count }
    var lifted: Range<Int> { declared.count ..< table.count }

    // What each declaration calls, beside the spelling it was declared
    // by. Read off the bodies as they were judged, so what a link walks is
    // what was proved rather than what a second reading of the same text
    // would find.
    let calls: [[Name]]

    // What the build read off a body whose declaration wrote no `returns`,
    // by the spelling it was declared under and in this document's own
    // type numbers. A declaration that wrote its answer is not here:
    // what an author wrote stands on the row.
    //
    // Read off a body rather than out of a signature, so it is the one
    // thing a document compiled against this cannot work out for itself
    // without reading the body again.
    let answers: [Name: LoweredType]

    // Where this document's lowered bodies number their calls and their
    // types from. A body carries the document's own numbers, so this is
    // what a link reads to turn them into rows.
    let numbering: Numbering
    let typeNumbering: LoweredTypeNumbering

    // What this document's variables start a run holding, in the order
    // the layouts read them.
    let variables: [(name: Name, value: Value)]

    // MARK: - Initializer
    init(
        document: Place.Document,
        types: [Name: TypeExpression],
        constraints: [Name: [TypeExpression]],
        contracts: [Name: [Name: Signature]],
        claims: [Name: Set<Name>],
        leaned: [Claim: Place],
        declared: [Name],
        table: [Judged],
        calls: [[Name]],
        answers: [Name: LoweredType],
        numbering: Numbering,
        typeNumbering: LoweredTypeNumbering,
        variables: [(name: Name, value: Value)]
    ) {
        self.document = document
        self.types = types
        self.constraints = constraints
        self.contracts = contracts
        self.claims = claims
        self.leaned = leaned
        self.declared = declared
        self.table = table
        self.calls = calls
        self.answers = answers
        self.numbering = numbering
        self.typeNumbering = typeNumbering
        self.variables = variables
    }

    // The same, where the parts were read apart and what has to be true is how
    // they stand to each other. Each one alone says nothing wrong; a table
    // shorter than the spellings it stands for, or a variable numbered past
    // the ones this holds, is a fact about two of them.
    //
    // This is the only door that sees all of them, so it is the only place
    // those facts can be asked.
    init(
        document: Place.Document,
        types: [Name: TypeExpression],
        constraints: [Name: [TypeExpression]],
        contracts: [Name: [Name: Signature]],
        claims: [Name: Set<Name>],
        leaned: [Claim: Place],
        declared: [Name],
        table: [Judged],
        calls: [[Name]],
        answers: [Name: LoweredType],
        numbering: Numbering,
        typeNumbering: LoweredTypeNumbering,
        judging variables: [(name: Name, value: Value)]
    ) throws {
        guard declared.count <= table.count else {
            throw ArtifactRefused(
                "an artifact declares \(declared.count) row(s) in a table of \(table.count)"
            )
        }

        guard calls.count == declared.count else {
            throw ArtifactRefused(
                "an artifact writes \(calls.count) call list(s) for \(declared.count) declaration(s)"
            )
        }

        // Which row a spelling stands for is read off where it stands in this
        // list, and which code a native row brings is read off the row's own
        // label. The two answer the same question, so a list that names them
        // in another order leaves every row knowing itself and every spelling
        // reaching somebody else.
        guard declared == table.prefix(declared.count).map(\.label) else {
            throw ArtifactRefused("an artifact declares its rows in an order its table does not")
        }

        // What a body reaches through a box of its own document. A run reads
        // one by standing at its number, so a number past the ones written
        // here is an array reached past its end.
        let holding = table.allSatisfy { row in
            guard case let .body(_, frame) = row.implementation else { return true }

            return frame.variables.allSatisfy { variable, _ in variable < variables.count }
        }

        guard holding else {
            throw ArtifactRefused(
                "a body stands on a variable past the \(variables.count) this document holds"
            )
        }

        // A closure stands its own row, and what it takes with it stands in
        // that row's frame. Which row it is, is this document's arithmetic:
        // the closures follow the declarations, in the order the document
        // numbered them. Only a list that has them all can ask this.
        let lifted = declared.count ..< table.count

        for row in table {
            guard case let .body(body, _) = row.implementation else { continue }

            for closure in body.standing.closures {
                guard let written = numbering.lifted(closure.number), written < lifted.count else {
                    throw ArtifactRefused(
                        "a body stands up a closure at \(closure.number), where this"
                            + " document numbers none"
                    )
                }

                guard case let .body(_, frame) = table[lifted.lowerBound + written].implementation,
                      closure.inner.allSatisfy({ slot in slot < frame.size })
                else {
                    throw ArtifactRefused(
                        "a closure takes something into a slot its own frame does not hold"
                    )
                }
            }
        }

        self.init(
            document: document,
            types: types,
            constraints: constraints,
            contracts: contracts,
            claims: claims,
            leaned: leaned,
            declared: declared,
            table: table,
            calls: calls,
            answers: answers,
            numbering: numbering,
            typeNumbering: typeNumbering,
            variables: variables
        )
    }

    // MARK: - Public
    // How an artifact is laid out, which is not how the language is versioned.
    // What a program needs of its runtime is said in the document; this says
    // only where the fields of an artifact stand, and it moves when they move
    // and for no other reason.
    static let format = 1

    // This artifact said as a value, so a caller can keep it where bytes are
    // kept. What carries it from there is the writing a document already
    // travels in, and a caller that reads it back is handed this again.
    //
    // Which document it belongs to is the first thing written, so an artifact
    // says which text it stands against and a caller holding two of them
    // cannot mistake one for the other.
    public var written: Value {
        get throws { .array([.int(Self.format), try ArtifactWriter().value(of: self)]) }
    }

    public init(written value: Value) throws {
        var fields = try Fields(value, of: "artifact format")
        let format = try fields.count()

        guard format == Self.format else {
            throw ArtifactRefused(
                "the artifact is laid out as format \(format), and this reads format \(Self.format)"
            )
        }

        self = try ArtifactReader().compiled(from: try fields.next())

        try fields.end()
    }
}

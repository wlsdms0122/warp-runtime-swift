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

    // What this was compiled against: the artifacts behind the declarations
    // this document named, each by its own fingerprint.
    //
    // Named and not every artifact the compile was handed. What a document
    // reaches outside itself is the procedures it calls and the types its
    // signatures name, and a document laid beside it that it never names
    // decides nothing about what it compiled to.
    //
    // Nothing where one of them has no fingerprint. An artifact says what it
    // is true against, and one that named some of what it leaned on and not
    // the rest would say it is true against less than it is. So it is not
    // written down at all, the same way a document that settles a procedure
    // into a value has no writing.
    let dependencies: [Fingerprint]?

    // What this artifact is, where a caller worked it out. Derived from the
    // bytes and so not something this can answer for itself: reading bytes is
    // another package's, and nothing here is allowed to learn how they are
    // written.
    //
    // A caller compiling against this hands it over as it kept it, and that is
    // what the next artifact records leaning on.
    public let fingerprint: Fingerprint?

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
        variables: [(name: Name, value: Value)],
        dependencies: [Fingerprint]?,
        fingerprint: Fingerprint? = nil
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
        self.dependencies = dependencies
        self.fingerprint = fingerprint
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
        judging variables: [(name: Name, value: Value)],
        dependencies: [Fingerprint]?,
        fingerprint: Fingerprint? = nil
    ) throws {
        guard declared.count <= table.count else {
            throw ArtifactRefused(
                "an artifact declares \(declared.count) row(s) in a table of \(table.count)"
            )
        }

        // The rows behind the declarations are the closures this document's
        // bodies lifted, and a numbering stands one number for each of them.
        // Two counts of the same run, so a numbering counting some other
        // number of them is numbering a table that is not this one.
        guard numbering.closureCount == table.count - declared.count else {
            throw ArtifactRefused(
                "an artifact numbers \(numbering.closureCount) closure(s) behind"
                    + " \(table.count - declared.count) row(s)"
            )
        }

        guard calls.count == declared.count else {
            throw ArtifactRefused(
                "an artifact writes \(calls.count) call list(s) for \(declared.count) declaration(s)"
            )
        }

        // What a variable is, is where it stands in this list: a body reaches
        // one by its number and never by its name. So the order is the fact,
        // and two entries swapped are two variables reading each other's start.
        guard variables.map(\.name).ordered else {
            throw ArtifactRefused("this document writes its variables out of name order")
        }

        // Which row a spelling stands for is read off where it stands in this
        // list, and which code a native row brings is read off the row's own
        // label. The two answer the same question, so a list that names them
        // in another order leaves every row knowing itself and every spelling
        // reaching somebody else.
        guard declared == table.prefix(declared.count).map(\.label) else {
            throw ArtifactRefused("an artifact declares its rows in an order its table does not")
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
            variables: variables,
            dependencies: dependencies,
            fingerprint: fingerprint
        )

        // What each row stands on, judged against the rows beside it. Asked
        // after the value stands, so the range its closures are cut by is the
        // one this type already says rather than the same arithmetic written
        // out again. A door that throws lets nothing past it.
        for row in table {
            try row.judge(
                standingIn: { number in frame(ofClosure: number, written: row.label) },
                reaching: reaches(_:),
                numbering: typeNumbering.types.indices.contains,
                membering: typeNumbering.memberships.indices.contains,
                holding: variables.count
            )
        }
    }

    // MARK: - Public
    // Which document this stands against, which is what a caller keeps it
    // under and hands back when it reads one.
    public var identity: Identity? {
        document.identity
    }

    // How an artifact is laid out, which is not how the language is versioned.
    // What a program needs of its runtime is said in the document; this says
    // only where the fields of an artifact stand, and it moves when they move
    // and for no other reason.
    static let format = 2

    // Which Warp wrote it. An artifact is what one implementation made of a
    // document, and what it made moves when that implementation moves: what a
    // body reaches decides purity, isolation and failure, and a declaration
    // that wrote no answer is read off its body. A reading that took an
    // artifact another build wrote would be reading a table laid out by rules
    // it no longer holds.
    //
    // Declared and not worked out. Every build system does it this way and none
    // of them asks the tool to prove what it is: rustc records the version that
    // made an `.rlib`, a `.swiftmodule` is bound to the compiler that wrote it,
    // and Cargo hashes what `rustc -vV` prints. What makes declaring safe is
    // that nobody types the value in. The release writes it, and it carries the
    // commit rather than the release alone, because a value a person remembers
    // to raise goes stale on the one commit it mattered.
    public static let runtime = "warp-swift 0.0.0-dev"

    // This artifact said as a value, so a caller can keep it where bytes are
    // kept. What carries it from there is the writing a document already
    // travels in, and a caller that reads it back is handed this again.
    //
    // Which document it belongs to and what it was compiled against are the
    // first two things written, so an artifact says what it stands against
    // before it says anything it stood on that.
    // Nothing where this document cannot be one. A document that settles a
    // procedure into a value holds what an artifact carries as data and a
    // procedure is not data, so it has no writing: that is a property of the
    // document and not something that went wrong, and a caller told to build
    // again would build the same document again.
    public var written: Value? {
        ArtifactWriter().value(of: self).map { written in
            .array([.int(Self.format), .string(Self.runtime), written])
        }
    }

    // The same artifact, said as what a caller worked out it is. Deriving that
    // answer reads bytes, so this is the door it arrives through, and a
    // document compiled against this one records what arrived here.
    public func fingerprinted(_ fingerprint: Fingerprint) -> Compiled {
        Compiled(
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
            variables: variables,
            dependencies: dependencies,
            fingerprint: fingerprint
        )
    }

    // Read back beside the document it was filed under, because what an
    // artifact says about which document it is, is the one thing about it
    // nothing else can check.
    //
    // An identity is derived and never declared, which is what makes it worth
    // having: nobody writes one down, so nobody writes one down wrongly. An
    // artifact does write one down. So a caller hands over the one it keeps
    // the artifact under, and an artifact saying it belongs somewhere else is
    // one that belongs to no cache this caller holds.
    // `fingerprint` is what the caller kept it under, carried in the same way
    // and for the same reason: an artifact cannot work out what it is, because
    // that answer is about bytes and reading bytes is another package's.
    public init(written value: Value, of identity: Identity?, fingerprint: Fingerprint? = nil) throws {
        var fields = try Fields(value, of: "artifact format")
        let format = try fields.count()

        guard format == Self.format else {
            throw ArtifactRefused(
                "the artifact is laid out as format \(format), and this reads format \(Self.format)"
            )
        }

        // Asked after the layout and before anything laid out by it. The layout
        // says where this field stands, and what it says is whether the rest of
        // them mean what this reading takes them to mean.
        let runtime = try fields.text()

        guard runtime == Self.runtime else {
            throw ArtifactRefused(
                "the artifact was compiled by \(runtime), and this is \(Self.runtime)"
            )
        }

        let written = try fields.next()

        try fields.end()

        // The same question the writing asks of what it lays down, asked of
        // what came back. A procedure is not data, and one read in would be
        // one this could never write out again: a reading whose answer will
        // not go back out the way it came in has read something else.
        guard !written.holdsProcedure else {
            throw ArtifactRefused(
                "this artifact settles a procedure into a value, and an"
                    + " artifact carries values as data"
            )
        }

        self = try ArtifactReader(of: identity, fingerprint: fingerprint).compiled(from: written)
    }

    // MARK: - Private
    // The frame of the row a body's closure number stands, or nothing where
    // this document numbers no closure there or numbers it for some other
    // declaration. Which row that is, is this document's own arithmetic.
    // Whether a number a body carries is one this document gave, and where it
    // stands for a closure, one this document stood up.
    private func reaches(_ number: Int) -> (taking: Int, standing: Bool)? {
        guard numbering.gave(number) else { return nil }

        guard let written = numbering.lifted(number) else {
            // A spelling, which this document may or may not declare. Where it
            // does, the row is here and what it takes is known.
            guard let name = numbering.reaching(number), let row = declared.firstIndex(of: name) else {
                return (taking: 0, standing: false)
            }

            return (taking: table[row].signature.names.count, standing: true)
        }

        guard written < lifted.count else { return nil }

        return (taking: table[lifted.lowerBound + written].signature.names.count, standing: true)
    }

    private func frame(ofClosure number: Int, written by: Name) -> Frame? {
        guard let written = numbering.lifted(number), written < lifted.count,
              numbering.writing(written) == by,
              case let .body(_, frame) = table[lifted.lowerBound + written].implementation
        else {
            return nil
        }

        return frame
    }
}

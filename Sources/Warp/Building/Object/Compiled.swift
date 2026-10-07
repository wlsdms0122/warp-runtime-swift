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
    // What tells this compile of the document from any other, where the
    // document was never written down and so has no identity. Minted once
    // per compile and carried by every value the compile made, so a closure
    // a fold settled says which document wrote it wherever the document is
    // laid.
    struct Token: Hashable, Sendable {
        // MARK: - Property
        private let id = UUID()

        // MARK: - Initializer
        init() {
        }

        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // Which document this is, so a refusal a build makes about it says
    // which text it is about.
    let document: Place.Document

    // What it declares in the two type tables, as it wrote them. A
    // link lays these down in the order it was handed the documents to
    // make the table its rows are numbered against, and reads no type of
    // this document anywhere else.
    let types: [Name: TypeExpression]
    let contracts: [Name: [Name: ContractProcedure]]

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
    // document's rows is cut by these, so nothing cuts them apart.
    var standing: Range<Int> { 0 ..< declared.count }
    var lifted: Range<Int> { declared.count ..< table.count }

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

    // What this was compiled against: the objects behind the declarations
    // this document named, each by its own fingerprint.
    //
    // Named and not every object the compile was handed. What a document
    // reaches outside itself is the procedures it calls and the types its
    // signatures name, and a document laid beside it that it never names
    // decides nothing about what it compiled to.
    //
    // Nothing where one of them has no fingerprint. An object says what it
    // is true against, and one that named some of what it leaned on and not
    // the rest would say it is true against less than it is. So it is not
    // written down at all, the same way a document that settles a procedure
    // into a value has no writing.
    let dependencies: [Fingerprint]?

    // What this object is, where a host worked it out. Derived from the
    // bytes and so not something this can answer for itself: reading bytes is
    // another package's, and nothing here is allowed to learn how they are
    // written.
    //
    // A host compiling against this hands it over as it kept it, and that is
    // what the next object records leaning on.
    public let fingerprint: Fingerprint?

    // The constants this document declared, by spelling. What they settled
    // to stands in the bodies that read them, and the spellings stay as the
    // names a closure may be written under.
    let constants: [Name]

    let token: Token

    // What a closure written by this document is spelled with: the text it
    // was read from, or this compile of it.
    var naming: Closure.Document {
        Closure.Document(identity: identity, token: token)
    }

    // The spellings its private declarations wear: rows of this document,
    // and in no table of names another document reads.
    let hidden: Set<Name>

    // Every name this document declares to the other documents of a link,
    // read off its tables: the dual of a module's `uses`.
    var declares: Set<Reference> {
        Set(
            declared.filter { name in !hidden.contains(name) }.map(Reference.procedure)
                + contracts.flatMap { contract, procedures in
                    procedures.keys.map { procedure in
                        Reference.procedure(ContractProcedure.spelling(of: contract, procedure: procedure))
                    }
                }
                + types.keys.map(Reference.type)
                + contracts.keys.map(Reference.type)
        )
    }

    // Which document this stands against, which is what a host keeps it
    // under and hands back when it reads one.
    public var identity: Identity? {
        document.identity
    }

    // MARK: - Initializer
    private init(
        document: Place.Document,
        types: [Name: TypeExpression],
        contracts: [Name: [Name: ContractProcedure]],
        claims: [Name: Set<Name>],
        leaned: [Claim: Place],
        declared: [Name],
        constants: [Name],
        table: [Judged],
        answers: [Name: LoweredType],
        numbering: Numbering,
        typeNumbering: LoweredTypeNumbering,
        variables: [(name: Name, value: Value)],
        dependencies: [Fingerprint]?,
        token: Token,
        fingerprint: Fingerprint? = nil
    ) {
        self.document = document
        self.constants = constants
        self.token = token
        self.types = types
        self.contracts = contracts
        self.claims = claims
        self.leaned = leaned
        self.declared = declared
        self.table = table
        self.hidden = Set(
            declared.enumerated()
                .filter { offset, _ in !table[offset].access.reachesOtherDocuments }
                .map(\.element)
        )
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
        contracts: [Name: [Name: ContractProcedure]],
        claims: [Name: Set<Name>],
        leaned: [Claim: Place],
        declared: [Name],
        constants: [Name],
        table: [Judged],
        answers: [Name: LoweredType],
        numbering: Numbering,
        typeNumbering: LoweredTypeNumbering,
        judging variables: [(name: Name, value: Value)],
        dependencies: [Fingerprint]?,
        token: Token = Token()
    ) throws {
        guard declared.count <= table.count else {
            throw ObjectRefused(
                "an object declares \(declared.count) row(s) in a table of \(table.count)"
            )
        }

        self.init(
            document: document,
            types: types,
            contracts: contracts,
            claims: claims,
            leaned: leaned,
            declared: declared,
            constants: constants,
            table: table,
            answers: answers,
            numbering: numbering,
            typeNumbering: typeNumbering,
            variables: variables,
            dependencies: dependencies,
            token: token
        )

        // The rows behind the declarations are the closures this document's
        // bodies lifted, and a numbering stands one number for each of them.
        // Two counts of the same run, so a numbering counting some other
        // number of them is numbering a table that is not this one.
        guard numbering.closureCount == lifted.count else {
            throw ObjectRefused(
                "an object numbers \(numbering.closureCount) closure(s) behind \(lifted.count) row(s)"
            )
        }

        // What each row stands on, judged against the rows beside it. Asked
        // after the value stands, so the range its closures are cut by is the
        // one this type already says rather than the same arithmetic written
        // out again. A door that throws lets nothing past it.
        for row in table {
            try row.judge(
                standingIn: frame(ofClosure:),
                reaching: reaches(_:),
                holding: variables.count,
                numberedBy: numbering
            )
        }
    }

    // Read back beside the document it was filed under, because what an
    // object says about which document it is, is the one thing about it
    // nothing else can check.
    //
    // An identity is derived and never declared, which is what makes it worth
    // having: nobody writes one down, so nobody writes one down wrongly. An
    // object does write one down. So a host hands over the one it keeps
    // the object under, and an object saying it belongs somewhere else is
    // one that belongs to no cache this host holds.
    //
    // `fingerprint` is what the host kept it under, carried in the same way
    // and for the same reason: an object cannot work out what it is, because
    // that answer is about bytes and reading bytes is another package's.
    public init(written value: Value, of identity: Identity?, fingerprint: Fingerprint? = nil) throws {
        let read = try ObjectReader(of: identity).compiled(from: value)

        self = fingerprint.map(read.fingerprinted) ?? read
    }

    // MARK: - Public
    // Which closure the row at a position is, its writer and which of the
    // writer's, for a row a closure was lifted into, and nil for a
    // declaration's own row. The numbering's arithmetic, asked here once for
    // both the link and a compile laying this document down.
    func closure(ofRow index: Int) -> (by: Closure.Declaration, nth: Int)? {
        guard lifted.contains(index) else { return nil }

        return numbering.writer(of: index - lifted.lowerBound)
    }

    // This object said as a value, so a host can keep it where bytes are
    // kept, or what keeps it from being one.
    public func object() throws(ObjectUnwritable) -> Value {
        try ObjectWriter().value(of: self)
    }

    // The same object, said as what it was worked out to be.
    //
    // Reached through the build and not on its own. A document is compiled
    // against what stands before it, so what it leaned on has to be known while
    // it compiles: an object fingerprinted after the fact is one every
    // document beside it already finished leaning on nothing it could name.
    func fingerprinted(_ fingerprint: Fingerprint) -> Compiled {
        Compiled(
            document: document,
            types: types,
            contracts: contracts,
            claims: claims,
            leaned: leaned,
            declared: declared,
            constants: constants,
            table: table,
            answers: answers,
            numbering: numbering,
            typeNumbering: typeNumbering,
            variables: variables,
            dependencies: dependencies,
            token: token,
            fingerprint: fingerprint
        )
    }

    // MARK: - Private
    // What the row a number a body carries stands for takes, where that row
    // is this document's own. Which row that is, is the numbering's answer; a
    // row another document holds, or a number this document never gave, is
    // the link's.
    private func reaches(_ number: Int) -> Int? {
        if let written = numbering.lifted(number) {
            return table[lifted.lowerBound + written].signature.names.count
        }

        guard let row = numbering.declaring(number) else { return nil }

        return table[row].signature.names.count
    }

    // The frame of the row a body's closure number stands, or nothing where
    // this document numbers no closure there.
    private func frame(ofClosure number: Int) -> Frame? {
        guard let written = numbering.lifted(number),
            case let .body(_, frame) = table[lifted.lowerBound + written].implementation
        else {
            return nil
        }

        return frame
    }
}

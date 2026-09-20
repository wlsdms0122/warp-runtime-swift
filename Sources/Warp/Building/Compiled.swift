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

    // What this object is, where a caller worked it out. Derived from the
    // bytes and so not something this can answer for itself: reading bytes is
    // another package's, and nothing here is allowed to learn how they are
    // written.
    //
    // A caller compiling against this hands it over as it kept it, and that is
    // what the next object records leaning on.
    public let fingerprint: Fingerprint?

    // The constants this document declared, by spelling. What they settled
    // to stands in the bodies that read them, and the spellings stay as the
    // names a closure may be written under.
    let constants: [Name]

    // What tells this compile of the document from any other, where the
    // document was never written down and so has no identity. Minted once
    // per compile and carried by every value the compile made, so a closure
    // a fold settled says which document wrote it wherever the document is
    // laid.
    struct Token: Hashable, Sendable {
        private let id = UUID()

        init() {}
    }

    let token: Token

    // What a closure written by this document is spelled with: the text it
    // was read from, or this compile of it.
    var naming: Closure.Document {
        Closure.Document(identity: identity, token: token)
    }

    // MARK: - Initializer
    private init(
        document: Place.Document,
        types: [Name: TypeExpression],
        constraints: [Name: [TypeExpression]],
        contracts: [Name: [Name: Signature]],
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
        self.constraints = constraints
        self.contracts = contracts
        self.claims = claims
        self.leaned = leaned
        self.declared = declared
        self.table = table
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
        constants: [Name],
        table: [Judged],
        answers: [Name: LoweredType],
        numbering: Numbering,
        typeNumbering: LoweredTypeNumbering,
        judging variables: [(name: Name, value: Value)],
        dependencies: [Fingerprint]?,
        token: Token = Token(),
        fingerprint: Fingerprint? = nil
    ) throws {
        guard declared.count <= table.count else {
            throw ObjectRefused(
                "an object declares \(declared.count) row(s) in a table of \(table.count)"
            )
        }

        // The rows behind the declarations are the closures this document's
        // bodies lifted, and a numbering stands one number for each of them.
        // Two counts of the same run, so a numbering counting some other
        // number of them is numbering a table that is not this one.
        guard numbering.closureCount == table.count - declared.count else {
            throw ObjectRefused(
                "an object numbers \(numbering.closureCount) closure(s) behind"
                    + " \(table.count - declared.count) row(s)"
            )
        }

        self.init(
            document: document,
            types: types,
            constraints: constraints,
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

        // What each row stands on, judged against the rows beside it. Asked
        // after the value stands, so the range its closures are cut by is the
        // one this type already says rather than the same arithmetic written
        // out again. A door that throws lets nothing past it.
        for row in table {
            try row.judge(
                standingIn: frame(ofClosure:),
                reaching: reaches(_:),
                holding: variables.count
            )
        }
    }

    // MARK: - Public
    // Which of its writer's closures the row at a position is, for a row a
    // closure was lifted into, and nil for a declaration's own row. The
    // numbering's arithmetic, asked here once for both the link and a compile
    // laying this document down.
    func nth(ofRow index: Int) -> Int? {
        guard lifted.contains(index) else { return nil }

        return numbering.writer(of: index - lifted.lowerBound)?.nth
    }

    // Every name this document declares, as a link asks for them. The exact
    // dual of a module's `uses`, and held here for the reason that one is held
    // there: a reader assembling it from the four tables is one more place to
    // fix when a fifth kind of declaration arrives, and forgetting that place
    // is a name that quietly declares nothing.
    var declares: Set<Reference> {
        Set(
            declared.map(Reference.procedure)
                + types.keys.map(Reference.type)
                + constraints.keys.map(Reference.type)
                + contracts.keys.map(Reference.type)
        )
    }

    // Which document this stands against, which is what a caller keeps it
    // under and hands back when it reads one.
    public var identity: Identity? {
        document.identity
    }

    // How an object is laid out: the format under *objects* in the
    // specification, which moves when the layout moves and for no other
    // reason. Which Warp wrote it is not written, because what an object
    // holds is the language's and any implementation of it reads any
    // other's.
    static let format = 1

    // The key an object says its format under, which is also what tells an
    // object from a document at the door: a document says `warp`.
    static let formatKey: Name = "object"

    // This object said as a value, so a caller can keep it where bytes are
    // kept. What carries it from there is the writing a document already
    // travels in, and a caller that reads it back is handed this again.
    //
    // Which document it belongs to and what it was compiled against are the
    // first two things written, so an object says what it stands against
    // before it says anything it stood on that.
    // Nothing on any of four counts, and none is something that went wrong.
    // A document numbered by a link's rows is no object. A build handed no
    // way to work a fingerprint out leaves every document that leaned on
    // another unable to say what it is true against. A value holding a
    // closure a document nobody wrote down wrote holds what no object can
    // spell. And a value holding a closure that holds a box of the run that
    // folded it holds what no object carries. Which one it was is what
    // `object()` says.
    public var written: Value? {
        try? object()
    }

    // The same, saying why there is none where there is none.
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
            constraints: constraints,
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

    // Read back beside the document it was filed under, because what an
    // object says about which document it is, is the one thing about it
    // nothing else can check.
    //
    // An identity is derived and never declared, which is what makes it worth
    // having: nobody writes one down, so nobody writes one down wrongly. An
    // object does write one down. So a caller hands over the one it keeps
    // the object under, and an object saying it belongs somewhere else is
    // one that belongs to no cache this caller holds.
    // `fingerprint` is what the caller kept it under, carried in the same way
    // and for the same reason: an object cannot work out what it is, because
    // that answer is about bytes and reading bytes is another package's.
    public init(written value: Value, of identity: Identity?, fingerprint: Fingerprint? = nil) throws {
        self = try ObjectReader(of: identity, fingerprint: fingerprint).compiled(from: value)
    }

    // MARK: - Private
    // Whether a number a body carries is one this document gave, and where it
    // stands for a row of this document, what that row takes. Which row that
    // is, is the numbering's answer; a row another document holds is the
    // link's.
    private func reaches(_ number: Int) -> (taking: Int, standing: Bool)? {
        guard numbering.gave(number) else { return nil }

        guard let written = numbering.lifted(number) else {
            guard let row = numbering.declaring(number) else { return (taking: 0, standing: false) }

            return (taking: table[row].signature.names.count, standing: true)
        }

        guard written < lifted.count else { return nil }

        return (taking: table[lifted.lowerBound + written].signature.names.count, standing: true)
    }

    // The frame of the row a body's closure number stands, or nothing where
    // this document numbers no closure there.
    private func frame(ofClosure number: Int) -> Frame? {
        guard let written = numbering.lifted(number), written < lifted.count,
              case let .body(_, frame) = table[lifted.lowerBound + written].implementation
        else {
            return nil
        }

        return frame
    }
}

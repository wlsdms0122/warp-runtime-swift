//
//  Module.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What one document declares. A build takes it with the others, and a run
// names the declaration it starts from.
public struct Module: Sendable {
    // MARK: - Property
    // The document this was made from. What a module declares is what its
    // document declared, so it is held rather than copied out field by field:
    // a listing that names them one at a time loses a new one silently.
    private let source: Draft

    // Metadata only. Which document a thing came out of is `identity`.
    public var description: String? { source.description }

    // The names this module uses and does not declare. Everything else here is
    // what the module declares; this is what it asks of whatever it is linked
    // with, and a link that does not declare all of them cannot run it.
    //
    // Exactly what it uses, always: every procedure it sends and every type
    // and contract it names without declaring. A host lays the link from this
    // list, so a list saying less would be trusted and wrong, and one saying
    // more asks for what the program has no use for. Which of those the module
    // is refused for is `Validator`'s to say.
    //
    // Spellings and not kinds: a spelling here asks for whatever the link
    // declares under it, so a module using the procedure and the type of one
    // spelling lists it once. Which kinds it uses is `references`.
    public let imports: Set<Name>

    // The claims other documents make that this one stands on. What a claim
    // is about is a pair and not a name, so it is listed apart.
    public var importedClaims: Set<ClaimPair> { source.importedClaims }

    // The same fact said as lookups rather than as a grant, the kind riding on
    // each. Read where the module is made, since a link asks each module it is
    // handed for them and the text they are read off does not move.
    let sends: Set<Name>
    let references: Set<Reference>

    // How many closure literals each declaration wrote. A closure's number is
    // the document's fact, so it is counted with the document.
    let closures: [Closure.Declaration: Int]

    // What this supplies to a link under a spelling another document may
    // name: its types, and the procedures that are not private. One answer,
    // read by everything that asks which module supplies a reference.
    let supplies: Set<Reference>

    // Types this module declares: each name bound to a struct's fields or to
    // the type an alias stands for.
    public var types: [Name: TypeDeclaration] { source.types }

    // Contracts this module declares: a name bound to the procedures a value's
    // type must answer to stand under it. A contract is an open set of types,
    // and a claim puts a type in it.
    public var contracts: [Name: Contract] { source.contracts }

    // Which contracts each type this document names answers, by the head it
    // says so under. A type answers a contract because a document says it
    // does, and this is where one says it. The build holds the claim to the
    // type's members within what this document stands on.
    public var claims: [Head: Set<Name>] { source.claims }

    // The procedures this module gives each type, by the head it gives them
    // under. A contract's procedure is answered by the member of that name.
    public var members: [Head: Set<Name>] { source.members }

    // The types this module gives each type, by the head it gives them under
    // and the name each is given. A contract's type is answered by the type
    // member of that name.
    public var typeMembers: [Head: [Name: TypeExpression]] { source.typeMembers }

    // Names bound to values, settled at the build and gone by run time,
    // private to the module: a constant is read by writing its name, and a
    // name is the module's scope.
    public var constants: [Name: Expression] { source.constants }

    // Names bound to boxes this module's procedures share for one run. Private
    // to the module the way a constant is, and for the same reason: a name is
    // a scope question. Another module changes one only through a procedure
    // declared beside it.
    public var variables: [Name: ModuleVariable] { source.variables }

    // What it declares as the program reads it: a member's signature holds
    // the type parameters its head names to the head's bounds. The draft
    // keeps each as written.
    public let procedures: [Name: Procedure]

    // Which document this was read out of, where it was read out of one.
    //
    // Nil where nobody said which document this came out of: a module a caller
    // built has no text under it at all, and a reader is told which text it is
    // reading rather than working it out. Deriving one means writing the
    // document back to its canonical bytes, which is not what reading a
    // document is for.
    public let identity: Identity?

    // Which document this is as a place reads it: the identity, and where the
    // text gave each type what it gave it. Worked out once, since every
    // refusal about this module stands in it.
    let document: Place.Document

    // Whether these are the procedures the specification names rather than
    // ones a host brought. A constant settles from a body in the link and
    // from these alone: what one of these answers is the same in every
    // implementation, so a value folded through one still means what it says
    // wherever the object it was written into is read.
    //
    // A document cannot say it about itself. It is what an implementation
    // brings, so it is written where the module is assembled and does not
    // travel with the draft.
    public let builtin: Bool

    // What this declares, on its own and without the checking. It is what a
    // writing takes, so a module and a document that was never a module are
    // written by one call, and `imports` here is the resolved list.
    public var draft: Draft {
        source.resolving(imports)
    }

    // The key a document says its language version under, which is what tells a
    // document from anything else at a door: an object says `object` where a
    // document says this.
    public static let versionKey: Name = "warp"

    // MARK: - Initializer
    // Making one is checking one, so a module that came in any way (a reader,
    // a serialization, a caller assembling types in Swift) has been checked
    // against itself.
    //
    // The imports are a claim, and nil is no claim. A reader hands over what
    // the text wrote and a drifting list is refused; a caller assembling types
    // in Swift says nothing and the module states the fact instead. Either way
    // `imports` afterwards is what the module uses.
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        importedClaims: Set<ClaimPair> = [],
        types: [Name: TypeDeclaration] = [:],
        contracts: [Name: Contract] = [:],
        claims: [Head: Set<Name>] = [:],
        members: [Head: Set<Name>] = [:],
        typeMembers: [Head: [Name: TypeExpression]] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: Expression] = [:],
        procedures: [Name: Procedure] = [:],
        identity: Identity? = nil,
        builtin: Bool = false
    ) throws {
        try self.init(
            description: description,
            imports: imports,
            importedClaims: importedClaims,
            types: types,
            contracts: contracts,
            claims: claims,
            members: members,
            typeMembers: typeMembers,
            constants: constants,
            variables: variables.mapValues { start in ModuleVariable(start) },
            procedures: procedures,
            identity: identity,
            builtin: builtin
        )
    }

    // The same, with variables that may say what they hold.
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        importedClaims: Set<ClaimPair> = [],
        types: [Name: TypeDeclaration] = [:],
        contracts: [Name: Contract] = [:],
        claims: [Head: Set<Name>] = [:],
        members: [Head: Set<Name>] = [:],
        typeMembers: [Head: [Name: TypeExpression]] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: ModuleVariable],
        procedures: [Name: Procedure] = [:],
        identity: Identity? = nil,
        builtin: Bool = false
    ) throws {
        try self.init(
            Draft(
                description: description,
                imports: imports,
                importedClaims: importedClaims,
                types: types,
                contracts: contracts,
                claims: claims,
                members: members,
                typeMembers: typeMembers,
                constants: constants,
                variables: variables,
                procedures: procedures
            ),
            identity: identity,
            builtin: builtin
        )
    }

    // A draft, checked. Which text it came out of is beside it rather than in
    // it: a draft is what a document declares, and which document that was is
    // the reader's to say.
    public init(_ draft: Draft, identity: Identity? = nil, builtin: Bool = false) throws {
        self.init(reading: draft, identity: identity, builtin: builtin)

        try Validator().validate(self)
    }

    // A draft this package wrote in Swift, standing without the check. Nothing
    // from outside reaches this, so what the check would refuse is a mistake
    // in this source, and the assertion is where it shows.
    package init(unchecked draft: Draft, builtin: Bool = false) {
        self.init(reading: draft, identity: nil, builtin: builtin)

        assert((try? Validator().validate(self)) != nil, "a module this package wrote checks against itself")
    }

    private init(reading draft: Draft, identity: Identity?, builtin: Bool) {
        self.source = draft
        self.procedures = draft.placed()
        self.identity = identity
        self.document = Place.Document(identity: identity, types: draft.types, members: draft.members)
        self.builtin = builtin
        let reading = draft.read()

        self.sends = reading.sends
        self.imports = draft.imports ?? reading.uses
        self.references = Set(reading.sends.map(Reference.procedure))
            .union(reading.mentions.map(Reference.type))
            .union(draft.importedClaims.map(Reference.claim))
        self.closures = reading.closures
        let hidden = Set(draft.procedures.filter { _, procedure in !procedure.access.reachesOtherDocuments }.keys)
        self.supplies = Set(draft.declaredProcedures.subtracting(hidden).map(Reference.procedure))
            .union(draft.declaredTypes.map(Reference.type))
            .union(draft.claimedPairs.map(Reference.claim))
    }

    // MARK: - Public
    // MARK: - Private
}

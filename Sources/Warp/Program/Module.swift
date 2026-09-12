//
//  Module.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What one document declares, and nothing about running.
//
// A module is not a procedure and cannot be run. It becomes runnable only when a
// builder is handed it together with the others and told which name to start
// from. Which declaration that is stays an argument to linking rather than a
// property one of them carries, so there is no marking to put on a declaration
// and no reserved name.
public struct Module: Sendable {
    // MARK: - Property
    // The document this was made from. What a module declares is what its
    // document declared, so it is held rather than copied out field by field:
    // a listing that names them one at a time loses a new one silently.
    private let source: Draft

    // Metadata only. Which document a thing came out of is `identity`.
    public var description: String? { source.description }

    // The procedures this module sends and does not declare. Everything else here is
    // what the module declares; this is what it asks of whatever it is linked
    // with, and a link that does not declare all of them cannot run it.
    //
    // Exactly what it sends, always: a caller granting from this list would
    // otherwise grant a procedure the program never uses, or link a program that
    // sends one the list never mentioned. Which of those two the module is
    // refused for is `Validator`'s to say.
    public let imports: Set<Name>

    // The same fact said as lookups rather than as a grant: the procedures this
    // calls, and every procedure and shape it names and does not declare. Read
    // where the module is made, since a link asks each module it is handed for
    // them and the text they are read off does not move.
    let sends: Set<Name>
    let uses: Set<Reference>

    // How many closure literals each declaration wrote. A closure's number is
    // the document's fact, so it is settled with the document.
    let closures: [Name: Int]

    // What this declares, by the name a link resolves to it. Where each one
    // was written is not here: a refusal that names a place reads it off the
    // draft, and every other reader wants the names alone.
    let declaredProcedures: Set<Name>
    let declaredShapes: Set<Name>

    // Shapes this module declares. A type is a name bound to a
    // `TypeExpression`, which is the same thing a procedure is with a body in
    // place of a type. A module declares, and what it declares differs only in
    // what kind of thing the name stands for.
    public var types: [Name: TypeExpression] { source.types }

    // Constraints this module declares: a name bound to the types a bounded
    // parameter under that name admits. Declared the same way a type is and
    // kept apart from the types, because nothing is ever *of* a constraint. It
    // bounds `some T`, and a slot cannot declare it directly.
    public var constraints: [Name: [TypeExpression]] { source.constraints }

    // Contracts this module declares: a name bound to the procedures a value must
    // answer to stand under it.
    //
    // Kept apart from the constraints for the reason the two are different
    // questions. A constraint is a closed set of shapes and a value of one is
    // one of them; a contract is an open set, and what puts a type in it is
    // that it declares the procedures. Only one of those can be judged by listing.
    public var contracts: [Name: [Name: Signature]] { source.contracts }

    // Which contracts each type this document names answers. A type answers a
    // contract because a document says it does, and this is where one says it.
    // Which declarations back the claim is the link's to find and to hold the
    // claim to.
    public var claims: [Name: Set<Name>] { source.claims }

    // Names bound to values, settled at link and gone by run time. Private to
    // the module: a constant is read by writing its name, and a name is a scope
    // question, so exporting one would need a second name table in path
    // position. Where a declared spelling cannot be told from drilling into a
    // record.
    public var constants: [Name: Expression] { source.constants }

    // Names bound to boxes this module's procedures share for one run. Private
    // to the module the way a constant is, and for the same reason: a name is
    // a scope question. Another module changes one only through a procedure
    // declared beside it.
    public var variables: [Name: Expression] { source.variables }

    public var procedures: [Name: Procedure] { source.procedures }

    // Which document this was read out of, where it was read out of one.
    //
    // Nil where nobody said which document this came out of: a module a caller
    // built has no text under it at all, and a reader is told which text it is
    // reading rather than working it out. Deriving one means writing the
    // document back to its canonical bytes, which is not what reading a
    // document is for.
    public let identity: Identity?

    // MARK: - Initializer
    // Making one is checking one, so a module that exists has been checked
    // against itself.
    //
    // A document arrives through a reader, a serialization or a caller
    // assembling shapes in Swift, and each of those is a way in. A check that
    // sat on one of them would leave the others open, and what comes through
    // them is the same module. Here there is one way in.
    //
    // What linking then reads a body for is names across modules, and it reads
    // one on the footing that a body introduces no name the module bound. That
    // footing is this call.
    //
    // The imports are a claim, and nil is no claim. A document makes one (it
    // travelled, and what it said about itself is the thing worth holding it
    // to) so a reader hands over what the text wrote and a drifting list is
    // refused. A caller assembling shapes in Swift has the module in hand and
    // nobody to disclose it to, so it says nothing and the module states the
    // fact instead. Either way `imports` afterwards is what the module sends.
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
        contracts: [Name: [Name: Signature]] = [:],
        claims: [Name: Set<Name>] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: Expression] = [:],
        procedures: [Name: Procedure],
        identity: Identity? = nil
    ) throws {
        try self.init(
            Draft(
                description: description,
                imports: imports,
                types: types,
                constraints: constraints,
                contracts: contracts,
                claims: claims,
                constants: constants,
                variables: variables,
                procedures: procedures
            ),
            identity: identity
        )
    }

    // A draft, checked. Which text it came out of is beside it rather than in
    // it: a draft is what a document declares, and which document that was is
    // the reader's to say.
    public init(_ draft: Draft, identity: Identity? = nil) throws {
        self.source = draft
        self.identity = identity
        let reading = draft.read()

        self.sends = reading.sends
        self.imports = draft.imports ?? reading.sends
        self.uses = Set(reading.sends.map(Reference.procedure))
            .union(reading.mentions.map(Reference.shape))
        self.closures = reading.closures
        self.declaredProcedures = reading.declaredProcedures
        self.declaredShapes = reading.declaredShapes

        try Validator().validate(self)
    }

    // MARK: - Public
    // What this declares, on its own and without the checking. It is what a
    // writing takes, so a module and a document that was never a module are
    // written by one call, and `imports` here is the resolved list rather than
    // the claim, since by now the two are the same.
    public var draft: Draft {
        source.resolving(imports)
    }

    // MARK: - Private
}

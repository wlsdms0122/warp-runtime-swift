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
// linker is handed it together with the others and told which name to start
// from. Which declaration that is stays an argument to linking rather than a
// property one of them carries, so there is no marking to put on a declaration
// and no reserved name.
public struct Module: Sendable {
    // MARK: - Property
    // Metadata only. Which document a thing came out of is `identity`.
    public let description: String?

    // The words this module sends and does not declare. Everything else here is
    // what the module declares; this is what it asks of whatever it is linked
    // with, and a link that does not declare all of them cannot run it.
    //
    // Exactly what it sends, always: a caller granting from this list would
    // otherwise grant a word the program never uses, or link a program that
    // sends one the list never mentioned. Which of those two the module is
    // refused for is `Validator`'s to say.
    public let imports: Set<Name>

    // The same fact said as lookups rather than as a grant: every word and
    // shape this names and does not declare, and the bare spellings its paths
    // step to. Read where the module is made, since a link asks each module it
    // is handed for both and the text they are read off does not move.
    let uses: Set<Reference>
    let walks: Set<Name>

    // The words a path could reach among the ones this declares, as far as
    // this document decides it.
    let walkableWords: Set<Name>

    // Shapes this module declares. A type is a name bound to a
    // `TypeExpression`, which is the same thing a procedure is with a body in
    // place of a type. A module declares, and what it declares differs only in
    // what kind of thing the name stands for.
    public let types: [Name: TypeExpression]

    // Constraints this module declares: a name bound to the types a bounded
    // parameter under that name admits. Declared the same way a type is and
    // kept apart from the types, because nothing is ever *of* a constraint. It
    // bounds `some T`, and a slot cannot declare it directly.
    public let constraints: [Name: [TypeExpression]]

    // Contracts this module declares: a name bound to the words a value must
    // answer to stand under it.
    //
    // Kept apart from the constraints for the reason the two are different
    // questions. A constraint is a closed set of shapes and a value of one is
    // one of them; a contract is an open set, and what puts a type in it is
    // that it declares the words. Only one of those can be judged by listing.
    public let contracts: [Name: [Name: Signature]]

    // Which contracts each type this document names answers. A type answers a
    // contract because a document says it does, and this is where one says it.
    // Which declarations back the claim is the link's to find and to hold the
    // claim to.
    public let claiming: [Name: Set<Name>]

    // Names bound to values, settled at link and gone by run time. Private to
    // the module: a constant is read by writing its name, and a name is a scope
    // question, so exporting one would need a second name table in path
    // position. Where a declared spelling cannot be told from drilling into a
    // record.
    public let constants: [Name: Expression]

    // Names bound to boxes this module's procedures share for one run. Private
    // to the module the way a constant is, and for the same reason: a name is
    // a scope question. Another module changes one only through a procedure
    // declared beside it.
    public let variables: [Name: Expression]

    public let procedures: [Name: Procedure]

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
        walked: Set<Name> = [],
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
        contracts: [Name: [Name: Signature]] = [:],
        claiming: [Name: Set<Name>] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: Expression] = [:],
        procedures: [Name: Procedure],
        identity: Identity? = nil
    ) throws {
        try self.init(
            Draft(
                description: description,
                imports: imports,
                walked: walked,
                types: types,
                constraints: constraints,
                contracts: contracts,
                claiming: claiming,
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
        self.description = draft.description
        self.types = draft.types
        self.constraints = draft.constraints
        self.contracts = draft.contracts
        self.claiming = draft.claiming
        self.constants = draft.constants
        self.variables = draft.variables
        self.procedures = draft.procedures
        self.identity = identity
        self.imports = draft.imports ?? draft.sends.union(draft.walked)
        self.uses = draft.uses
        self.walks = draft.walks
        self.walkableWords = draft.walkableWords

        try Validator().validate(self)
    }

    // MARK: - Public
    // What this declares, on its own and without the checking. It is what a
    // writing takes, so a module and a document that was never a module are
    // written by one call, and `imports` here is the resolved list rather than
    // the claim, since by now the two are the same.
    public var draft: Draft {
        Draft(
            description: description,
            imports: imports,
            types: types,
            constraints: constraints,
            contracts: contracts,
            claiming: claiming,
            constants: constants,
            variables: variables,
            procedures: procedures
        )
    }

    // MARK: - Internal
    var sends: Set<Name> { draft.sends }


    // MARK: - Private
}

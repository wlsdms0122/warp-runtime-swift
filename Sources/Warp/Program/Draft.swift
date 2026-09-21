//
//  Draft.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a document declares, before anything has been held to the language's
// rules. A draft is not a module: it cannot be linked and cannot be run, and
// the only thing that takes one is the module's initializer, which is where the
// checking is.
//
// It exists because two questions are asked of one text and only one of them is
// about the program. What a document *is* (which is what telling one document
// from another is done on) is answered by writing it back out, and a document
// with a name nothing declares is still a document. So the writing takes a
// draft, and a text nobody can run still has a canonical form and an identity.
public struct Draft: Sendable {
    // MARK: - Property
    public let description: String?

    // What the document said it imports, and nil where it said nothing. A
    // module resolves this; here it is still only what was written.
    // Settable only from here, so `resolving(_:)` changes this one field of a
    // copy instead of naming every field to keep it.
    public private(set) var imports: Set<Name>?

    public let types: [Name: TypeExpression]
    public let constraints: [Name: [TypeExpression]]

    // Contracts this module declares: a name bound to the procedures a value must
    // answer to stand under it. Each procedure is a signature the implementing
    // declaration is held to, written without the receiver, which is the
    // implementing type itself.
    public let contracts: [Name: [Name: ContractProcedure]]

    // Which contracts each type this document names answers, by the name of
    // the type. A type answers a contract because a document says it does: the
    // link holds the claim to the declarations that back it, and a declaration
    // named for a type and a procedure nobody claimed is that document's procedure and
    // nothing more.
    //
    // Said here rather than beside the type, because the type may be another
    // document's. A document that arrives later gives a type it did not
    // declare the procedures a contract asks, and saying it beside the type would
    // leave that document nowhere to say it.
    public let claims: [Name: Set<Name>]

    public let constants: [Name: Expression]

    // Names bound to boxes the document's procedures share, each holding what
    // its expression settles to when a run starts. Declared like a constant
    // and read by the same spelling; unlike a constant, a body may write one.
    public let variables: [Name: Expression]

    // Settable only from here, the way `imports` is, so `declaring(_:)`
    // changes this one field of a copy.
    public private(set) var procedures: [Name: Procedure]

    // MARK: - Initializer
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
        contracts: [Name: [Name: ContractProcedure]] = [:],
        claims: [Name: Set<Name>] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: Expression] = [:],
        procedures: [Name: Procedure]
    ) {
        self.description = description
        self.imports = imports
        self.types = types
        self.constraints = constraints
        self.contracts = contracts
        self.claims = claims
        self.constants = constants
        self.variables = variables
        self.procedures = procedures
    }

    // The same document declaring these procedures instead.
    public func declaring(_ procedures: [Name: Procedure]) -> Draft {
        var held = self
        held.procedures = procedures

        return held
    }

    // The same document with the imports it turned out to have. A module
    // settles them from what the text sends, and a writing of that module
    // takes the settled list.
    public func resolving(_ imports: Set<Name>) -> Draft {
        var held = self
        held.imports = imports

        return held
    }

    // MARK: - Internal
    // What this declares in the procedure namespace, each under the place it was
    // written at. A contract's procedure is one of them, by the spelling a call
    // writes to reach it, and its place is the two steps the document nests it
    // in rather than the joined name in one.
    func procedures(in document: Place.Document) -> [(name: Name, place: Place)] {
        procedures.keys.map { name in
            (name, Place.procedure(name.spelling, in: document))
        }
            + contracts.flatMap { contract, procedures in
                procedures.keys.map { procedure in
                    (
                        Name(normal: "\(contract.spelling).\(procedure.spelling)"),
                        Place.contract(contract.spelling, in: document)
                            .appending(.key(procedure.spelling))
                    )
                }
            }
    }

    // What this declares in the type namespace, the same way. Types,
    // constraints and contracts share it: a link refuses a name standing for a type
    // and a membership at once.
    func types(in document: Place.Document) -> [(name: Name, place: Place)] {
        types.keys.map { name in
            (name, Place.type(name.spelling, in: document))
        }
            + constraints.keys.map { name in
                (name, Place.constraint(name.spelling, in: document))
            }
            + contracts.keys.map { name in
                (name, Place.contract(name.spelling, in: document))
            }
    }

    // The two together, by the reference a link resolves to each. Read off the
    // lists above rather than gathered again, so what a document declares is
    // said in one place whichever side asks.
    func declarations(in document: Place.Document) -> [(reference: Reference, place: Place)] {
        procedures(in: document).map { declared in (.procedure(declared.name), declared.place) }
            + types(in: document).map { declared in (.type(declared.name), declared.place) }
    }

    // The same two, when only the names are wanted. Read off the lists above
    // rather than gathered again, so what counts as a procedure and what counts as
    // a type is said in one place.
    var declaredProcedures: Set<Name> {
        read().declaredProcedures
    }

    var declaredTypes: Set<Name> {
        read().declaredTypes
    }

    // Every name this uses and does not itself declare, which is what `imports`
    // says where a document wrote one.
    public var uses: Set<Name> {
        read().uses
    }

    // What reading a document once answers: what it declares, what it leans on
    // another document for, and how many closures each of its declarations
    // wrote.
    //
    // One value rather than one question at a time, because every one of these
    // is answered by walking the same text and the same tables. Asking for them
    // apart walks the document once for each.
    struct Reading: Sendable {
        let sends: Set<Name>

        // The types this names and does not itself declare. Read off the
        // declarations and off the bodies alike: a local binding says what it
        // holds, a cast asks for a type, and a closure literal writes a
        // signature of its own.
        let mentions: Set<Name>

        // What this declares, by the name a link resolves to it.
        let declaredProcedures: Set<Name>
        let declaredTypes: Set<Name>

        // The two as one list of spellings, which is what a document's
        // `imports` holds.
        var uses: Set<Name> { sends.union(mentions) }

        // How many closure literals each declaration wrote, at whatever depth.
        // A closure inside a closure counts with the rest: what the number
        // tells apart is which of its declaration's closures this is, and
        // nesting does not change that.
        //
        // A constant and a variable are expressions like a body, so a closure
        // written in one is the document's the way a closure written in a body
        // is. The same three the document is read over everywhere else.
        //
        // Read off the document so a closure's number is the document's fact.
        // The link lowers the procedures before the rest, and which declarations
        // are procedures depends on the whole graph, so a count taken while
        // lowering would move when an unrelated module joins.
        let closures: [Name: Int]
    }

    // What this document says it leans on and how many closures it wrote,
    // read in one walk over its text.
    //
    // Every one of these is answered by walking the same expressions, so
    // asking for them apart walks the text once for each. A document is made
    // once and read by every link it stands in, and this is where that reading
    // happens.
    func read() -> Reading {
        let declaredProcedures = Set(procedures(in: .assembled).map(\.name))
        let declaredTypes = Set(types(in: .assembled).map(\.name))

        // A native procedure's sends are its own declaration rather than something
        // read off a body, since a Swift body is not text this could read. A
        // list that missed them would understate what the module does, which
        // is the one thing this list may not do.
        var sent = Set(
            procedures.values.flatMap { procedure in
                procedure.implementation.nativeImports?.map(\.selector) ?? []
            }
        )
        var named: Set<Name> = []
        var counts: [Name: Int] = [:]

        func fold(_ name: Name, _ held: some Traversable) {
            var written = 0

            for found in held.nodes {
                switch found {
                case let .statement(statement):
                    guard let declared = statement.binding?.declared else { continue }

                    named.formUnion(declared.mentions)

                case let .expression(expression):
                    switch expression {
                    case let .call(call):
                        sent.insert(call.selector)

                    case let .cast(_, type, _):
                        named.formUnion(type.mentions)

                    case let .closure(procedure):
                        written += 1
                        named.formUnion(procedure.signature.mentions)

                    default:
                        break
                    }
                }
            }

            counts[name] = written
        }

        for type in types.values {
            named.formUnion(type.mentions)
        }

        for members in constraints.values {
            for member in members {
                named.formUnion(member.mentions)
            }
        }

        for procedures in contracts.values {
            for asked in procedures.values {
                named.formUnion(asked.signature.mentions)
            }
        }

        // A claim names two types, and both are mentions like any other: the
        // type it is about and the contract it says that type answers. The
        // link reads the contract's procedures to hold the claim to them, so a
        // document making one stands behind the document that wrote it.
        for (type, contracts) in claims {
            named.insert(type)
            named.formUnion(contracts)
        }

        for (name, procedure) in procedures {
            named.formUnion(procedure.signature.mentions)

            guard let block = procedure.block else { continue }

            fold(name, block)
        }

        for (name, expression) in constants {
            fold(name, expression)
        }

        for (name, expression) in variables {
            fold(name, expression)
        }

        return Reading(
            sends: sent.subtracting(declaredProcedures),
            mentions: named.subtracting(declaredTypes),
            declaredProcedures: declaredProcedures,
            declaredTypes: declaredTypes,
            closures: counts
        )
    }

    // MARK: - Private
}

//
//  Draft.swift
//  Warp
//
//  Created by JSilver on 9/1/26.
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
    // What reading a document once answers: what it declares, what it leans on
    // another document for, and how many closures each of its declarations
    // wrote.
    //
    // One value, since every one of these is read by one walk of the text.
    struct Reading: Sendable {
        // MARK: - Property
        let sends: Set<Name>

        // The types this names and does not itself declare. Read off the
        // declarations and off the bodies alike: a local binding says what it
        // holds, a cast asks for a type, and a closure literal writes a
        // signature of its own.
        let mentions: Set<Name>

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
        // is. A procedure and a constant may be spelled alike, so each is
        // counted under its kind.
        //
        // Read off the document so a closure's number is the document's fact.
        let closures: [Closure.Declaration: Int]

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    public let description: String?

    // What the document said it imports, and nil where it said nothing. A
    // module resolves this; here it is still only what was written.
    public private(set) var imports: Set<Name>?

    public let types: [Name: TypeDeclaration]

    // Contracts this module declares: a name bound to the procedures a value's
    // type must answer to stand under it. Each procedure is a signature the
    // implementing declaration is held to, taking `Self`, the type answering
    // the contract, first, where the implementing declaration takes its own
    // type.
    public let contracts: [Name: [Name: ContractProcedure]]

    // Which contracts each type this document names answers, by the name of
    // the type. A type answers a contract because a document says it does: the
    // link holds the claim to the declarations that back it, and a declaration
    // named for a type and a procedure nobody claimed is that document's procedure and
    // nothing more. The type may be another document's.
    public let claims: [Name: Set<Name>]

    public let constants: [Name: Expression]

    // Names bound to boxes the document's procedures share, each holding what
    // its start settles to when a run starts, under the type it declares or
    // the start's. Declared like a constant and read by the same spelling;
    // unlike a constant, a body may write one.
    public let variables: [Name: ModuleVariable]

    public private(set) var procedures: [Name: Procedure]

    // Every name this uses and does not itself declare, which is what `imports`
    // says where a document wrote one.
    public var uses: Set<Name> {
        read().uses
    }

    // What this declares in the procedure namespace. A contract's procedure is
    // one of them, by the spelling a call writes to reach it.
    var declaredProcedures: Set<Name> {
        Set(procedures.keys).union(contracts.flatMap { contract, procedures in
            procedures.keys.map { procedure in ContractProcedure.spelling(of: contract, procedure: procedure) }
        })
    }

    // What this declares in the type namespace. Types and contracts share
    // it: the build refuses a name standing for a type and a contract at
    // once.
    var declaredTypes: Set<Name> {
        Set(types.keys).union(contracts.keys)
    }

    // MARK: - Initializer
    public init(
        description: String? = nil,
        imports: Set<Name>? = nil,
        types: [Name: TypeDeclaration] = [:],
        contracts: [Name: [Name: ContractProcedure]] = [:],
        claims: [Name: Set<Name>] = [:],
        constants: [Name: Expression] = [:],
        variables: [Name: ModuleVariable] = [:],
        procedures: [Name: Procedure] = [:]
    ) {
        self.description = description
        self.imports = imports
        self.types = types
        self.contracts = contracts
        self.claims = claims
        self.constants = constants
        self.variables = variables
        self.procedures = procedures
    }

    // MARK: - Public
    // The same document declaring these procedures instead.
    public func declaring(_ procedures: [Name: Procedure]) -> Draft {
        var held = self
        held.procedures = procedures

        return held
    }

    // The same document with the imports it turned out to have. A module
    // works them out from what the text sends, and a writing of that module
    // takes that list.
    public func resolving(_ imports: Set<Name>) -> Draft {
        var held = self
        held.imports = imports

        return held
    }

    // What this document says it leans on and how many closures it wrote,
    // read in one walk over its text.
    func read() -> Reading {
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
        var counts: [Closure.Declaration: Int] = [:]

        func fold(_ declaration: Closure.Declaration, _ held: some Traversable) {
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

            counts[declaration] = written
        }

        for type in types.values {
            named.formUnion(type.mentions)
        }

        for procedures in contracts.values {
            for asked in procedures.values {
                named.formUnion(asked.signature.mentions)
            }
        }

        // A claim names two types, and both are mentions like any other: the
        // type it is about and the contract it says that type answers. The
        // link reads the contract's procedures to hold the claim to them, so a
        // document making one stands behind the document that wrote it. A type
        // the language names is no document's to stand behind.
        for (type, contracts) in claims {
            if TypeExpression.nominalTypes[type] == nil {
                named.insert(type)
            }

            named.formUnion(contracts)
        }

        for (name, procedure) in procedures {
            named.formUnion(procedure.signature.mentions)

            guard let block = procedure.block else { continue }

            fold(.procedure(name), block)
        }

        for (name, expression) in constants {
            fold(.binding(name), expression)
        }

        for (name, variable) in variables {
            fold(.binding(name), variable.start)

            if let declared = variable.declared {
                named.formUnion(declared.mentions)
            }
        }

        return Reading(
            sends: sent.subtracting(declaredProcedures),
            mentions: named.subtracting(declaredTypes).subtracting(Prelude.names),
            closures: counts
        )
    }

    // MARK: - Private
}

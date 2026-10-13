//
//  TypeTable.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The type table: every type the modules in a link declared, and what each
// name stands for. `types` keeps each declaration as written; `loweredTypes`
// expands every alias and keeps a declared struct a row, so a struct that
// names itself is a row and not a regress.
public struct TypeTable: Sendable {
    // MARK: - Property
    public let types: [Name: TypeDeclaration]

    // Contracts declared in this link: a name bound to the procedures a value's
    // type must answer. A contract is an open set of types, and a claim puts a
    // type in it.
    public let contracts: [Name: Contract]

    // What the documents give each type under each name, by the type's name
    // and the member's: one member each, whichever document gave it.
    public let typeMembers: [Name: [Name: TypeMember]]

    // The same declarations as the run reads them, lowered once here. Every
    // judgement this table answers is asked of the lowered one.
    let loweredTypes: LoweredTypeTable

    // The link these rows are numbered against, kept so the table can be
    // remade with what a later pass worked out and still hand back the rows a
    // body already holds.
    private let linkage: Linkage

    // The order the rows stand in, where a link said one. Kept for the same
    // reason the linkage is: remaking the table has to hand back the rows a
    // body already holds.
    private let standing: [Name]?

    // A table declaring nothing, for a judgement asked with no declarations
    // behind it.
    static let empty = TypeTable(types: [:], of: Linkage())

    // MARK: - Initializer
    // A table a caller assembled: declarations and not a link, so no row
    // made by one is at home in it. They are held to what a document
    // declaring them is held to, by the same judges, so a name nothing
    // declares and a name that is no struct and comes back to itself are
    // refused here, in the words a document is refused in.
    init(
        types: [Name: TypeDeclaration] = [:],
        contracts: [Name: Contract] = [:]
    ) throws {
        let declaring = try Module(types: types, contracts: contracts)
        let table = try DeclarationChecker().types(
            of: try TypeNamespace([declaring]),
            standing: [declaring],
            numbered: Linkage()
        )

        try DeclarationChecker().judge([declaring], in: table)

        self = table
    }

    // The same declarations as one link's, which owns the identity its rows
    // are numbered against.
    init(
        types: [Name: TypeDeclaration],
        contracts: [Name: Contract] = [:],
        typeMembers: [TypeMember] = [],
        satisfying: [Name: [Name: Head]] = [:],
        standing: [Name]? = nil,
        of linkage: Linkage
    ) {
        self.types = types
        self.contracts = contracts
        self.typeMembers = typeMembers.reduce(into: [:]) { given, member in
            given[member.head.type, default: [:]][member.name] = member
        }
        self.standing = standing
        self.linkage = linkage
        // Every declared contract has an entry, so a contract's name stands
        // as one wherever a type is asked for, whether or not the claims
        // have been gathered yet.
        self.loweredTypes = LoweredTypeTable.lowering(
            types,
            contracts: contracts,
            satisfying: satisfying.merging(
                contracts.keys.map { contract in (contract, [Name: Head]()) }
            ) { held, _ in held },
            typeMembers: typeMembers,
            standing: standing,
            of: linkage
        )
    }

    // MARK: - Public
    // The same declarations with the claims of what an asker stands on in
    // them. Which types answer a contract is read off the documents' claims,
    // and a compile asks it of the claims within each document's reach, so
    // the table is remade per asker rather than holding an answer it did not
    // have. The rows are the first table's: only what answers changes.
    func satisfying(_ satisfying: [Name: [Name: Head]], holdsEveryClaim: Bool) -> TypeTable {
        TypeTable(
            types: types,
            contracts: contracts,
            typeMembers: typeMembers,
            loweredTypes: loweredTypes.satisfying(
                satisfying.merging(contracts.keys.map { contract in (contract, [Name: Head]()) }) { held, _ in held },
                holdsEveryClaim: holdsEveryClaim
            ),
            standing: standing,
            of: linkage
        )
    }

    // MARK: - Private
    private init(
        types: [Name: TypeDeclaration],
        contracts: [Name: Contract],
        typeMembers: [Name: [Name: TypeMember]],
        loweredTypes: LoweredTypeTable,
        standing: [Name]?,
        of linkage: Linkage
    ) {
        self.types = types
        self.contracts = contracts
        self.typeMembers = typeMembers
        self.loweredTypes = loweredTypes
        self.standing = standing
        self.linkage = linkage
    }
}

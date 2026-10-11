//
//  TypeTable.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The type table: every type the modules in a link declared, and what each
// name stands for. A named type is kept rather than expanded, so a type that
// names itself is a row and not a regress.
public struct TypeTable: Sendable {
    // MARK: - Property
    public let types: [Name: TypeExpression]

    // Contracts declared in this link: a name bound to the procedures a value's
    // type must answer. A contract is an open set of types, and a claim puts a
    // type in it.
    public let contracts: [Name: [Name: ContractProcedure]]

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
    public static let empty = TypeTable(types: [:], of: Linkage())

    // MARK: - Initializer
    // A table a caller assembled: declarations and not a link, so no row
    // made by one is at home in it. They are held to what a document
    // declaring them is held to, by the same judges, so a name nothing
    // declares and a name that is no record and comes back to itself are
    // refused here, in the words a document is refused in.
    public init(
        types: [Name: TypeExpression] = [:],
        contracts: [Name: [Name: ContractProcedure]] = [:]
    ) throws {
        let declaring = try Module(types: types, contracts: contracts, procedures: [:])
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
        types: [Name: TypeExpression],
        contracts: [Name: [Name: ContractProcedure]] = [:],
        satisfying: [Name: Set<Name>] = [:],
        settled: Bool = false,
        unsettled: Fulfillment? = nil,
        standing: [Name]? = nil,
        of linkage: Linkage
    ) {
        self.types = types
        self.contracts = contracts
        self.standing = standing
        self.linkage = linkage
        // Every declared contract has an entry, so a contract's name stands
        // as one wherever a type is asked for, whether or not the claims
        // have been gathered yet.
        self.loweredTypes = LoweredTypeTable.lowering(
            types,
            satisfying: satisfying.merging(
                contracts.keys.map { contract in (contract, Set<Name>()) }
            ) { held, _ in held },
            settled: settled,
            unsettled: unsettled,
            standing: standing,
            of: linkage
        )
    }

    // MARK: - Public
    // The same declarations with the satisfaction worked out. Which types
    // answer a contract is read off the documents' claims, which are gathered
    // after this table is first built, so the table is remade rather than
    // holding an answer it did not have. The rows are numbered from the
    // declarations alone, so they are the rows the first table had. The
    // answer is settled where every document is in, which is where nothing
    // is left unsettled to write down.
    func satisfying(
        _ satisfying: [Name: Set<Name>],
        unsettled: Fulfillment? = nil
    ) -> TypeTable {
        TypeTable(
            types: types,
            contracts: contracts,
            satisfying: satisfying,
            settled: unsettled == nil,
            unsettled: unsettled,
            standing: standing,
            of: linkage
        )
    }

    // MARK: - Private
}

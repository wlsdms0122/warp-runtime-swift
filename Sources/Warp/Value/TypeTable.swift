//
//  TypeTable.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The type table: every type the modules in a link declared, and what each
// name stands for. The counterpart of `Library` on the other axis. That one
// holds the procedures a caller installed, this one the types a document declared.
//
// It exists because a named type is kept rather than expanded. Expanding at link
// would make a self-naming type a regress, so the name survives into the run and
// something has to be able to answer it.
//
// Constraints live beside the types rather than among them. A constraint is a
// name for a membership (which types a bounded parameter admits) and nothing is
// ever *of* one, so a slot cannot declare it and a value cannot arrive as it.
// Two tables keep the two questions apart: "what type is this name" and "what
// does this name admit".
public struct TypeTable: Sendable {
    // MARK: - Property
    public let types: [Name: TypeExpression]
    public let constraints: [Name: [TypeExpression]]

    // Contracts declared in this link: a name bound to the procedures a value must
    // answer. Beside the constraints for the same reason those are beside the
    // types. A membership is a closed set of types and a contract is the open
    // set of types that declare some procedures, so listing answers one and not
    // the other.
    public let contracts: [Name: [Name: Signature]]

    // The same declarations as the run reads them, lowered once here. Every
    // judgment this table answers is asked of the lowered one.
    let loweredTypes: LoweredTypeTable

    // The link these rows are numbered against, kept so the table can be
    // remade with what a later pass worked out and still hand back the rows a
    // body already holds.
    private let linkage: Linkage

    // The order the rows of each space stand in, where a link said one. Kept
    // for the same reason the linkage is: remaking the table has to hand back
    // the rows a body already holds.
    private let standing: [Name]?
    private let constraintStanding: [Name]?

    // A table declaring nothing, for a judgment asked with no declarations
    // behind it.
    public static let empty = TypeTable()

    // MARK: - Initializer
    // A table a caller assembled: declarations and not a link, so no row
    // made by one is at home in it.
    public init(
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:],
        contracts: [Name: [Name: Signature]] = [:]
    ) {
        self.init(types: types, constraints: constraints, contracts: contracts, of: Linkage())
    }

    // The same declarations as one link's, which owns the identity its rows
    // are numbered against.
    init(
        types: [Name: TypeExpression],
        constraints: [Name: [TypeExpression]],
        contracts: [Name: [Name: Signature]] = [:],
        satisfying: [Name: Set<Name>] = [:],
        unsettled: Fulfillment? = nil,
        standing: [Name]? = nil,
        constraintStanding: [Name]? = nil,
        of linkage: Linkage
    ) {
        self.types = types
        self.constraints = constraints
        self.contracts = contracts
        self.standing = standing
        self.constraintStanding = constraintStanding
        self.linkage = linkage
        self.loweredTypes = LoweredTypeTable.lowering(
            types,
            constraints: constraints,
            satisfying: satisfying,
            unsettled: unsettled,
            standing: standing,
            constraintStanding: constraintStanding,
            of: linkage
        )
    }

    // MARK: - Public
    // The same declarations with the satisfaction worked out. Which types
    // answer a contract is read off the documents' claims, which are gathered
    // after this table is first built, so the table is remade rather than
    // holding an answer it did not have. The rows are numbered from the
    // declarations alone, so they are the rows the first table had.
    func satisfying(
        _ satisfying: [Name: Set<Name>],
        unsettled: Fulfillment? = nil
    ) -> TypeTable {
        TypeTable(
            types: types,
            constraints: constraints,
            contracts: contracts,
            satisfying: satisfying,
            unsettled: unsettled,
            standing: standing,
            constraintStanding: constraintStanding,
            of: linkage
        )
    }

    public func resolve(_ name: Name) -> TypeExpression? {
        types[name]
    }

    public func constraint(_ name: Name) -> [TypeExpression]? {
        constraints[name]
    }

    // Whether a reading could be a member of a constraint, or nil when nothing
    // declares the name. The caller says what an undeclared constraint means on
    // its surface, rather than this deciding for both. Membership is one-sided
    // the way every judgment before the run is: only what is provably outside
    // is refused, and a reading nothing can be said about (`any`, or another
    // type parameter with no constraint of its own) passes here and is judged
    // again where the value actually arrives.
    //
    // A constrained reading is judged by its own membership rather than by its
    // name: it stands for some member of its constraint, so it fits where every
    // one of those members would. The table ends its own recursion (a
    // membership already being asked answers yes rather than being asked again)
    // so a table built by hand refuses or answers where a linked one would, and
    // never chases a declaration the link would have refused.
    public func admits(constraint name: Name, reading: TypeExpression) -> Bool? {
        guard let row = loweredTypes.constraintRow(named: name) else { return nil }

        return loweredTypes.admits(constraint: row, reading: reading.lowered(in: loweredTypes), assuming: [])
    }

    // The same membership, asked of a value at the boundary. Nil again
    // where nothing declares the constraint.
    public func admits(constraint name: Name, value: Value) -> Bool? {
        guard let row = loweredTypes.constraintRow(named: name) else { return nil }

        return loweredTypes.admits(constraint: row, value: value, assuming: [])
    }

    // MARK: - Private
}

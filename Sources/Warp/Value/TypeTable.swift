//
//  TypeTable.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The type table: every shape the modules in a link declared, and what each name
// stands for. The counterpart of `Library` on the other axis — that one holds
// the words a caller installed, this one the shapes a document declared.
//
// It exists because a named type is kept rather than expanded. Expanding at link
// would make a self-naming shape a regress, so the name survives into the run and
// something has to be able to answer it.
//
// Constraints live beside the types rather than among them. A constraint is a
// name for a membership — which types a bounded parameter admits — and nothing
// is ever *of* one, so a slot cannot declare it and a value cannot arrive as
// it. Two tables keep the two questions apart: "what shape is this name" and
// "what does this name admit".
public struct TypeTable: Sendable {
    // MARK: - Property
    public let types: [Name: TypeExpression]
    public let constraints: [Name: [TypeExpression]]

    // The same declarations as the run reads them, lowered once here. Every
    // judgment this table answers is asked of the lowered one.
    let shapes: ShapeTable

    // A table declaring nothing, for a judgment asked with no declarations
    // behind it.
    public static let empty = TypeTable()

    // MARK: - Initializer
    // A table a caller assembled: declarations and not a link, so no row
    // made by one is at home in it.
    public init(
        types: [Name: TypeExpression] = [:],
        constraints: [Name: [TypeExpression]] = [:]
    ) {
        self.init(types: types, constraints: constraints, of: .none)
    }

    // The same declarations as one link's, which owns the identity its rows
    // are numbered against.
    init(
        types: [Name: TypeExpression],
        constraints: [Name: [TypeExpression]],
        of linkage: Linkage
    ) {
        self.types = types
        self.constraints = constraints
        self.shapes = ShapeTable.lowering(types, constraints: constraints, of: linkage)
    }

    // MARK: - Public
    public func resolve(_ name: Name) -> TypeExpression? {
        types[name]
    }

    public func constraint(_ name: Name) -> [TypeExpression]? {
        constraints[name]
    }

    // Whether a reading could be a member of a constraint, or nil when nothing
    // declares the name — the caller says what an undeclared constraint means
    // on its surface, rather than this deciding for both. Membership is
    // one-sided the way every judgment before the run is: only what is
    // provably outside is refused, and a reading nothing can be said about —
    // `any`, or another type parameter with no constraint of its own — passes
    // here and is judged again where the value actually arrives.
    //
    // A constrained reading is judged by its own membership rather than by its
    // name: it stands for some member of its constraint, so it fits where
    // every one of those members would. The table ends its own recursion — a
    // membership already being asked answers yes rather than being asked
    // again — so a table built by hand refuses or answers where a linked one
    // would, and never chases a declaration the link would have refused.
    public func admits(constraint name: Name, reading: TypeExpression) -> Bool? {
        shapes.admits(constraint: name, reading: reading)
    }

    // The same membership, asked of a value at the boundary. Nil again
    // where nothing declares the constraint.
    public func admits(constraint name: Name, value: Value) -> Bool? {
        guard let row = shapes.constraintRow(named: name) else { return nil }

        return shapes.admits(constraint: row, value: value, assuming: [])
    }

    // MARK: - Private
}

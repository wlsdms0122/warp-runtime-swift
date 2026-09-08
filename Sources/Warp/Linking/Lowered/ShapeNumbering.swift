//
//  ShapeNumbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Where the shape rows in a document's lowered bodies come from, and which
// declaration each one stands for.
//
// A body stands on shapes as well as on calls, and the same rule holds for
// both: the number a document writes is the document's, and which row of a
// link it is stays the link's answer. So a document numbers the shapes its
// bodies stand on from itself, in name order, and a link that puts other
// documents beside it moves no number.
//
// The names are the ones its lowered code turned out to stand on rather than
// the ones its text spells. A shape reaches a body through what a path walked
// as well as through what an author wrote, and that reading is the link's, so
// what is in this space is read off the lowering and not off the document.
//
// Two lists, because a shape names two tables. A declared type and a
// membership are separate spaces and no name is in both.
struct ShapeNumbering: Sendable {
    // What a number turned out to be, with the reason where it is not a row:
    // a name the link does not declare, or a number the document never gave.
    enum Answer: Sendable {
        case row(Int)
        case unfound(Name)
        case unnumbered
    }

    // MARK: - Property
    private let space: Space

    // What runs while a link is still being made was lowered against that
    // link's table, so the number a body carries there is the row.
    static let link = ShapeNumbering()

    // MARK: - Initializer
    init(types: Set<Name>, memberships: Set<Name>) {
        space = .document(types: types.sorted(), memberships: memberships.sorted())
    }

    private init() {
        space = .link
    }

    // MARK: - Public
    // Which row of a link a number stands for, read from that link's table.
    // A number counted from the link is a row already, so it answers itself.
    func type(_ number: Int, in shapes: ShapeTable) -> Answer {
        guard case let .document(names, _) = space else { return .row(number) }
        guard names.indices.contains(number) else { return .unnumbered }

        let name = names[number]

        return shapes.row(named: name).map(Answer.row) ?? .unfound(name)
    }

    func membership(_ number: Int, in shapes: ShapeTable) -> Answer {
        guard case let .document(_, names) = space else { return .row(number) }
        guard names.indices.contains(number) else { return .unnumbered }

        let name = names[number]

        return shapes.constraintRow(named: name).map(Answer.row) ?? .unfound(name)
    }

    // The declarations this numbered, in the order it numbered them. Nil
    // where the numbers are a link's rows and nothing was numbered.
    //
    // The order is the whole of what a caller cannot work out for itself, so
    // it is read here rather than said twice.
    var declared: (types: [Name], memberships: [Name])? {
        guard case let .document(types, memberships) = space else { return nil }

        return (types, memberships)
    }

    // Where a number is counted from. The document's lists are the whole of
    // the difference: a number counted from the link is its own answer.
    private enum Space: Sendable {
        case document(types: [Name], memberships: [Name])
        case link
    }

    // MARK: - Private
}

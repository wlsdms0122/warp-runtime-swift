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
    private let types: [Name]
    private let memberships: [Name]

    // MARK: - Initializer
    init(types: Set<Name>, memberships: Set<Name>) {
        self.types = types.sorted()
        self.memberships = memberships.sorted()
    }

    // MARK: - Public
    // Which row of a link a number stands for, read from that link's table.
    func type(_ number: Int, in shapes: ShapeTable) -> Answer {
        guard types.indices.contains(number) else { return .unnumbered }

        let name = types[number]

        return shapes.row(named: name).map(Answer.row) ?? .unfound(name)
    }

    func membership(_ number: Int, in shapes: ShapeTable) -> Answer {
        guard memberships.indices.contains(number) else { return .unnumbered }

        let name = memberships[number]

        return shapes.constraintRow(named: name).map(Answer.row) ?? .unfound(name)
    }

    // The declarations this numbered, in the order it numbered them. The order
    // is the whole of what a caller cannot work out for itself, so it is read
    // here rather than said twice.
    var declared: (types: [Name], memberships: [Name]) {
        (types, memberships)
    }

    // MARK: - Private
}

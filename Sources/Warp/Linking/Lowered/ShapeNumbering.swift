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
// bodies name from itself, in name order, and a link that puts other
// documents beside it moves no number.
//
// The names are the ones its lowered code turned out to name rather than the
// ones its text spells. A shape reaches a body through what a path walked as
// well as through what an author wrote, and that reading is the link's, so
// what is in this space is read off the lowering and not off the document.
//
// Two lists, because a shape names two tables. A declared type and a
// membership are separate spaces and no name is in both.
struct ShapeNumbering: Sendable {
    // MARK: - Property
    // The declarations the document's bodies stand on, in name order. A
    // number one of those bodies carries is a place in one of these.
    let types: [Name]
    let memberships: [Name]

    private let typeNumbers: [Name: Int]
    private let membershipNumbers: [Name: Int]

    // MARK: - Initializer
    init(types: Set<Name>, memberships: Set<Name>) {
        let named = types.sorted()
        let bounded = memberships.sorted()

        self.types = named
        self.memberships = bounded
        self.typeNumbers = Self.placed(named)
        self.membershipNumbers = Self.placed(bounded)
    }

    // MARK: - Public
    // Where a shape standing on this declared type stands in the document's
    // numbering, and nil where the document's bodies name no such type.
    func type(_ name: Name) -> Int? {
        typeNumbers[name]
    }

    func membership(_ name: Name) -> Int? {
        membershipNumbers[name]
    }

    // MARK: - Private
    private static func placed(_ names: [Name]) -> [Name: Int] {
        names.enumerated().reduce(into: [Name: Int]()) { places, entry in
            places[entry.element] = entry.offset
        }
    }
}

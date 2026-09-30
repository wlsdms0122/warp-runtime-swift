//
//  LoweredTypeNumbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Where the type rows in a document's lowered bodies come from, and which
// declaration each one stands for.
//
// A body stands on types as well as on calls, and the same rule holds for
// both: the number a document writes is the document's, and which row of a
// link it is stays the link's resolution. So a document numbers the types its
// bodies stand on from itself, in name order, and a link that puts other
// documents beside it moves no number.
//
// The names are the ones its lowered code turned out to stand on rather than
// the ones its text spells. A type reaches a body through what a path walked
// as well as through what an author wrote, and that reading is the link's, so
// what is in this space is read off the lowering and not off the document.
//
// Two lists, because a type names two tables. A declared type and a
// membership are separate spaces and no name is in both.
struct LoweredTypeNumbering: Sendable {
    // What a number turned out to be, with the reason where it is not a row:
    // a name the link does not declare, or a number the document never gave.
    enum Resolution: Sendable {
        case row(Int)
        case unfound(Name)
        case unnumbered
    }

    // A document's type numbers resolved to the rows of one link, worked out
    // once per number rather than at every type standing on one.
    struct Rows {
        // MARK: - Property
        let types: [Resolution]
        let memberships: [Resolution]

        // MARK: - Initializer
        // MARK: - Public
        // One type a document wrote, read as this link's rows.
        func read(_ type: LoweredType, at place: Place) throws -> LoweredType {
            try type.renumbered(
                type: { number in try row(types, at: number, calling: "named", in: place) },
                membership: { number in
                    try row(memberships, at: number, calling: "bounding a parameter", in: place)
                }
            )
        }

        // MARK: - Private
        // Which row a document's type number turned out to be. The reading is
        // the numbering's; what to say when it does not resolve is this.
        private func row(
            _ resolutions: [Resolution],
            at number: Int,
            calling what: String,
            in place: Place
        ) throws -> Int {
            guard resolutions.indices.contains(number) else {
                throw BuildError.unjudged(
                    "a type standing at \(number), which its document never numbered",
                    at: place
                )
            }

            switch resolutions[number] {
            case let .row(row):
                return row

            case let .unfound(name):
                throw BuildError(
                    "'\(name)' is \(what) here, and no module in this link declares it",
                    at: place
                )

            case .unnumbered:
                throw BuildError.unjudged(
                    "a type standing at \(number), which its document never numbered",
                    at: place
                )
            }
        }
    }

    // MARK: - Property
    // The declarations this numbered, in name order: which names stand here
    // is what a caller cannot work out for itself, and the order is the
    // language's, so a reading holds a list to it.
    let types: [Name]
    let memberships: [Name]

    // The two lists said as one value, so an object carries what its bodies
    // number their types from.
    var written: Value {
        .array([
            .array(types.map { name in .string(name.spelling) }),
            .array(memberships.map { name in .string(name.spelling) })
        ])
    }

    // MARK: - Initializer
    init(types: Set<Name>, memberships: Set<Name>) {
        self.types = types.sorted()
        self.memberships = memberships.sorted()
    }

    // Read back from an object: the two lists, in this order.
    init(written value: Value) throws {
        var fields = try Fields(value, of: "type numbering")

        self.types = try Field(fields.next(), of: "type numbering types").ordered { written in
            try Field(written, of: "type numbering types").name()
        }
        self.memberships = try Field(fields.next(), of: "type numbering memberships").ordered { written in
            try Field(written, of: "type numbering memberships").name()
        }

        try fields.end()
    }

    // MARK: - Public
    // Every number this gave, resolved to the rows of one link.
    func rows(in loweredTypes: LoweredTypeTable) -> Rows {
        Rows(
            types: types.indices.map { number in type(number, in: loweredTypes) },
            memberships: memberships.indices.map { number in membership(number, in: loweredTypes) }
        )
    }

    // Which row of a link a number stands for, read from that link's table.
    func type(_ number: Int, in loweredTypes: LoweredTypeTable) -> Resolution {
        guard types.indices.contains(number) else { return .unnumbered }

        let name = types[number]

        return loweredTypes.row(named: name).map(Resolution.row) ?? .unfound(name)
    }

    func membership(_ number: Int, in loweredTypes: LoweredTypeTable) -> Resolution {
        guard memberships.indices.contains(number) else { return .unnumbered }

        let name = memberships[number]

        return loweredTypes.constraintRow(named: name).map(Resolution.row) ?? .unfound(name)
    }

    // MARK: - Private
}

//
//  LoweredTypeNumbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// Where the type rows in a document's lowered bodies, the answers read off
// them and its variables' starts come from, and which declaration each one
// stands for.
//
// A body stands on types as well as on calls, and the same rule holds for
// both: the number a document writes is the document's, and which row of a
// link it is stays the link's resolution. So a document numbers the types it
// stands on from itself, in name order, and a link that puts other documents
// beside it moves no number.
//
// The names are the ones its lowered code turned out to stand on rather than
// the ones its text spells. A type reaches a body through what a path walked
// as well as through what an author wrote, and that reading is the link's, so
// what is in this space is read off the lowering and not off the document.
//
// Only declared types are numbered. A contract a bound names is written by
// its name, since a contract stands on no row.
struct LoweredTypeNumbering: Sendable {
    // What a number turned out to be: a row, or the name the link does not
    // declare.
    enum Resolution: Sendable {
        case row(Int)
        case unfound(Name)
    }

    // A document's type numbers resolved to the rows of one link, worked out
    // once per number rather than at every type standing on one.
    struct Renumbering {
        // MARK: - Property
        let types: [Resolution]

        // MARK: - Initializer
        // MARK: - Public
        // One type a document wrote, read as this link's rows.
        func read(_ type: LoweredType, at place: Place) throws -> LoweredType {
            try type.replacingRows { number in .named(try row(types, at: number, in: place)) }
        }

        // MARK: - Private
        // Which row a document's type number turned out to be. The reading is
        // the numbering's; what to say when it does not resolve is this.
        private func row(
            _ resolutions: [Resolution],
            at number: Int,
            in place: Place
        ) throws -> Int {
            guard resolutions.indices.contains(number) else {
                throw BuildError("a type stands at \(number), which its document never numbered", at: place)
            }

            switch resolutions[number] {
            case let .row(row):
                return row

            case let .unfound(name):
                throw BuildError(
                    "'\(name)' is named here, and no module in this link declares it",
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

    // The list said as one value, so an object carries what its bodies
    // number their types from.
    var written: Value {
        .array(types.map { name in .string(name.spelling) })
    }

    // MARK: - Initializer
    init(types: Set<Name>) {
        self.types = types.sorted()
    }

    // Read back from an object: the names, in their order.
    init(written value: Value) throws {
        self.types = try Field(value, of: "type numbering").ordered { written in
            try Field(written, of: "type numbering").name()
        }
    }

    // MARK: - Public
    // Every number this gave, resolved to the rows of one link.
    func rows(in loweredTypes: LoweredTypeTable) -> Renumbering {
        Renumbering(
            types: types.map { name in loweredTypes.row(named: name).map(Resolution.row) ?? .unfound(name) }
        )
    }

    // MARK: - Private
}

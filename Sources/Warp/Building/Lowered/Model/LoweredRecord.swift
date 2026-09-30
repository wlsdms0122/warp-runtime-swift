//
//  LoweredRecord.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A record's fields as the build laid them out: the layout a value settling
// here is built on, and the type of the field at each of its places. One
// type per field, checked where the pair is made, so every reading may take
// the two together.
struct LoweredRecord: Sendable, Equatable {
    // MARK: - Property
    let layout: Layout
    let fields: [LoweredType]

    // The names beside the types, in the layout's order.
    var named: Zip2Sequence<[Name], [LoweredType]> {
        zip(layout.fields, fields)
    }

    // What a loop binds each round. The build judges a round against it and
    // the run builds each round on its layout, so the place the build lowers
    // is the place the value puts the field at.
    static let round = LoweredRecord(layout: Layout(name: nil, ordered: ["index"]), fields: [.int])

    // MARK: - Initializer
    // The same, where the two were read apart and the pairing is what has to be
    // true. The inner door is reached with a pairing this proved, which is what
    // makes its promise a fact rather than an assumption.
    init(layout: Layout, judging fields: [LoweredType]) throws {
        guard layout.fields.count == fields.count else {
            throw ObjectRefused(
                "a record names \(layout.fields.count) field(s) and holds \(fields.count)"
            )
        }

        self.init(layout: layout, fields: fields)
    }

    // The inner door: the maker already stands on the layout.
    init(layout: Layout, fields: [LoweredType]) {
        assert(layout.fields.count == fields.count, "a record has one type per field its layout names")

        self.layout = layout
        self.fields = fields
    }

    // MARK: - Public
    subscript(field: Name) -> LoweredType? {
        layout.position(of: field).map { place in fields[place] }
    }

    // MARK: - Private
}

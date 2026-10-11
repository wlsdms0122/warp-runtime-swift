//
//  LoweredRecord.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A record's fields as the build laid them out: the declared record's name,
// the field names in the order a value's fields stand, and the type of the
// field at each of those places. One type per field, checked where the pair is
// made, so every reading may take the two together.
//
// The name is a declared record's. A record literal reads under none until
// the place it is written into names it.
struct LoweredRecord: Sendable, Equatable {
    // MARK: - Property
    let name: Name?

    // In ascending byte order, as `Name`'s `<` orders them.
    let names: [Name]

    let fields: [LoweredType]

    // The names beside the types, in the layout's order.
    var named: Zip2Sequence<[Name], [LoweredType]> {
        zip(names, fields)
    }

    // The layout a value of the declared record is built on, and nil for a
    // literal's reading no place has named.
    var layout: Layout? {
        name.map { name in Layout(name: name, ordered: names) }
    }

    // MARK: - Initializer
    // The same, where the two were read apart and the pairing is what has to be
    // true. The inner door is reached with a pairing this proved, which is what
    // makes its promise a fact rather than an assumption.
    init(name: Name?, names: [Name], judging fields: [LoweredType]) throws {
        guard names.ordered else {
            throw ObjectRefused("a record's fields are not in name order")
        }

        guard names.count == fields.count else {
            throw ObjectRefused(
                "a record names \(names.count) field(s) and holds \(fields.count)"
            )
        }

        self.init(name: name, names: names, fields: fields)
    }

    // The inner door: the maker already put the names in order, one type each.
    init(name: Name?, names: [Name], fields: [LoweredType]) {
        assert(names.ordered && names.count == fields.count, "a record has one type per field it names, in name order")

        self.name = name
        self.names = names
        self.fields = fields
    }

    // MARK: - Public
    subscript(field: Name) -> LoweredType? {
        position(of: field).map { place in fields[place] }
    }

    // Where a field stands, or nil where the record does not name it.
    func position(of field: Name) -> Int? {
        names.firstIndex(of: field)
    }

    // The same fields, each type put through `transform`.
    func mapFields(_ transform: (LoweredType) throws -> LoweredType) rethrows -> LoweredRecord {
        LoweredRecord(name: name, names: names, fields: try fields.map(transform))
    }

    // MARK: - Private
}

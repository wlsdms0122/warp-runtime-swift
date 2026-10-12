//
//  LoweredStruct.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A declared struct's fields as the build laid them out: the struct's name,
// the field names in the order a value's fields stand, and the type of the
// field at each of those places. One type per field, checked where the pair is
// made, so every reading may take the two together.
struct LoweredStruct: Sendable, Equatable {
    // MARK: - Property
    let name: Name

    // In ascending byte order, as `Name`'s `<` orders them.
    let names: [Name]

    let fields: [LoweredType]

    // The names beside the types, in the layout's order.
    var named: Zip2Sequence<[Name], [LoweredType]> {
        zip(names, fields)
    }

    // The layout a value of the struct is built on.
    var layout: Layout {
        Layout(name: name, ordered: names)
    }

    // MARK: - Initializer
    // The maker already put the names in order, one type each.
    init(name: Name, names: [Name], fields: [LoweredType]) {
        assert(names.ordered && names.count == fields.count, "a struct has one type per field it names, in name order")

        self.name = name
        self.names = names
        self.fields = fields
    }

    // MARK: - Public
    subscript(field: Name) -> LoweredType? {
        position(of: field).map { place in fields[place] }
    }

    // Where a field stands, or nil where the struct does not name it.
    func position(of field: Name) -> Int? {
        names.firstIndex(of: field)
    }

    // The same fields, each type put through `transform`.
    func mapFields(_ transform: (LoweredType) throws -> LoweredType) rethrows -> LoweredStruct {
        LoweredStruct(name: name, names: names, fields: try fields.map(transform))
    }

    // MARK: - Private
}

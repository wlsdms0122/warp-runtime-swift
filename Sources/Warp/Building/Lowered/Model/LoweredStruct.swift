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
// made, so every reading may take the two together. A struct taking type
// parameters writes them in its fields, and a mention reads them as the types
// it is applied to.
struct LoweredStruct: Sendable, Equatable {
    // MARK: - Property
    let name: Name

    // In ascending byte order, as `Name`'s `<` orders them.
    let names: [Name]

    let fields: [LoweredType]

    // The type parameters, in the order a mention hands their types.
    let typeParameters: [Name]

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
    init(name: Name, names: [Name], fields: [LoweredType], typeParameters: [Name] = []) {
        assert(names.ordered && names.count == fields.count, "a struct has one type per field it names, in name order")

        self.name = name
        self.names = names
        self.fields = fields
        self.typeParameters = typeParameters
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
        LoweredStruct(name: name, names: names, fields: try fields.map(transform), typeParameters: typeParameters)
    }

    // The struct a mention applying it to `arguments` reads: every field with
    // each type parameter read as the type at its position. A mention holds
    // as many as the struct takes, since the build refuses any other count
    // where it is written and a door reads a value's off its fields.
    func applied(to arguments: [LoweredType]) -> LoweredStruct {
        guard !typeParameters.isEmpty else { return self }

        let filled = Dictionary(uniqueKeysWithValues: zip(typeParameters, arguments))

        return LoweredStruct(
            name: name,
            names: names,
            fields: fields.map { field in field.filling(filled) }
        )
    }

    // MARK: - Private
}

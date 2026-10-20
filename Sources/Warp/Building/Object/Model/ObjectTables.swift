//
//  ObjectTables.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

// The tables an object writes what nests into: a type, a lowered type, a
// value, an operation and an address each stand as an entry, and whatever
// holds one writes its number. So an object nests no deeper for a program
// nesting deeper.
struct ObjectTables<Table> {
    // MARK: - Property
    let types: Table
    let loweredTypes: Table
    let values: Table
    let operations: Table
    let addresses: Table

    // MARK: - Initializer
    init(_ table: (ObjectLayout.Key) throws -> Table) rethrows {
        self.types = try table(.typeTable)
        self.loweredTypes = try table(.loweredTypeTable)
        self.values = try table(.valueTable)
        self.operations = try table(.operationTable)
        self.addresses = try table(.addressTable)
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  Record.swift
//  Warp
//
//  Created by JSilver on 9/4/26.
//

import Foundation

// Fields at the places a `Layout` puts them. The names live in the layout, so
// two records of one layout share one copy of them, and a field is read by
// finding its place once rather than by carrying its name alongside its value.
public struct Record: Sendable {
    // MARK: - Property
    public let layout: Layout

    // In the layout's order, one value per field.
    public let values: [Value]

    public var name: Name? {
        layout.name
    }

    public var names: [Name] {
        layout.fields
    }

    public var count: Int {
        values.count
    }

    public var isEmpty: Bool {
        values.isEmpty
    }

    // MARK: - Initializer
    // A record of the fields a caller hands in, under a layout of their names.
    init(name: Name?, _ fields: [Name: Value]) {
        let ordered = fields.map { field in (name: field.key, value: field.value) }
            .sorted { one, other in one.name < other.name }

        self.layout = Layout(name: name, ordered: ordered.map(\.name))
        self.values = ordered.map(\.value)
    }

    // A layout filled from outside, where the values are as many as the
    // layout names and stand in its order.
    public init(layout: Layout, checking values: [Value]) throws {
        guard values.count == layout.fields.count else {
            throw ValueRefused(
                "a layout of \(layout.fields.count) fields was handed \(values.count) values"
            )
        }

        self.init(layout: layout, values: values)
    }

    // The inner door: the maker already stands on the layout.
    init(layout: Layout, values: [Value]) {
        self.layout = layout
        self.values = values
    }

    // This record's fields as names beside values, for a reader that walks
    // names rather than a layout.
    public var asDictionary: Value.Dictionary {
        Value.Dictionary(ordered: zip(layout.fields, values).map { name, value in (name: name, value: value) })
    }

    // MARK: - Public
    public subscript(field: Name) -> Value? {
        layout.position(of: field).map { place in values[place] }
    }

    // This record with one field written. A layout says which fields there
    // are, so a name it does not hold is not written but refused.
    public func writing(_ field: Name, with value: Value) throws -> Record {
        guard let place = layout.position(of: field) else {
            throw ValueRefused("\(layout.name.map { name in "\(name) " } ?? "")has no field '\(field)'")
        }

        var written = values
        written[place] = value

        return Record(layout: layout, values: written)
    }

    // This record with every value put through `transform`, under the same
    // layout.
    public func mapValues(_ transform: (Name, Value) throws -> Value) rethrows -> Record {
        Record(
            layout: layout,
            values: try zip(layout.fields, values).map { field, value in try transform(field, value) }
        )
    }

    // This record under another name, with the same fields.
    func named(_ name: Name?) -> Record {
        Record(layout: Layout(name: name, ordered: layout.fields), values: values)
    }

    // MARK: - Private
}

extension Record: Equatable {
    public static func == (lhs: Record, rhs: Record) -> Bool {
        lhs.layout == rhs.layout
            && zip(lhs.values, rhs.values).allSatisfy { mine, theirs in mine == theirs }
    }
}

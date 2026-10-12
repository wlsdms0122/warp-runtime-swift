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
public struct Record: Sendable, Equatable {
    // MARK: - Property
    public let layout: Layout

    // In the layout's order, one value per field.
    public let values: [Value]

    public var name: Name {
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
    init(name: Name, _ fields: [Name: Value]) {
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

    // The unchecked initializer: the maker already stands on the layout.
    init(layout: Layout, values: [Value]) {
        assert(layout.fields.count == values.count, "a record has one value per field its layout names")

        self.layout = layout
        self.values = values
    }

    // MARK: - Public
    public subscript(field: Name) -> Value? {
        layout.position(of: field).map { place in values[place] }
    }

    // This record with one field written. A layout says which fields there
    // are, so a name it does not hold is not written but refused.
    public func writing(_ field: Name, with value: Value) throws -> Record {
        guard let place = layout.position(of: field) else {
            throw ValueRefused("\(name) has no field '\(field)'")
        }

        return writing(at: place, with: value)
    }

    // The same, at the place the layout puts the field.
    func writing(at place: Int, with value: Value) -> Record {
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

    public static func == (lhs: Record, rhs: Record) -> Bool {
        lhs.layout == rhs.layout
            && zip(lhs.values, rhs.values).allSatisfy { mine, theirs in mine == theirs }
    }

    // MARK: - Private
}

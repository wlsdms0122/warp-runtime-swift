//
//  RecordShape.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A record's fields as the link laid them out: the layout a value settling
// here is built on, and the shape of the field at each of its places. One
// shape per field, checked where the pair is made, so every reading may take
// the two together.
struct RecordShape: Sendable, Equatable {
    // MARK: - Property
    let layout: Layout
    let fields: [Shape]

    // The names beside the shapes, in the layout's order.
    var named: Zip2Sequence<[Name], [Shape]> {
        zip(layout.fields, fields)
    }

    // MARK: - Initializer
    init(layout: Layout, fields: [Shape]) {
        precondition(
            layout.fields.count == fields.count,
            "a record shape has one shape per field its layout names"
        )

        self.layout = layout
        self.fields = fields
    }

    // MARK: - Public
    subscript(field: Name) -> Shape? {
        layout.position(of: field).map { place in fields[place] }
    }

    // MARK: - Private
}

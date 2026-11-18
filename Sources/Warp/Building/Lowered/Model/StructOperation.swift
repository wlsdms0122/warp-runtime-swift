//
//  StructOperation.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A struct literal as the run makes it: the layout the build made for it, and
// the code that fills each of its places. One field per place, checked where
// the pair is made, so the run reads the two together and never has to ask
// whether they still line up.
struct StructOperation: Sendable {
    // MARK: - Property
    let layout: Layout
    let fields: [Operation]

    // MARK: - Initializer
    // The same, where the two were read apart and the pairing is what has to be
    // true. The unchecked initializer is reached with a pairing this proved, which is what
    // makes its promise a fact rather than an assumption.
    init(layout: Layout, judging fields: [Operation]) throws {
        guard layout.fields.count == fields.count else {
            throw ObjectRefused(
                "a struct literal names \(layout.fields.count) field(s) and holds \(fields.count)"
            )
        }

        self.init(layout: layout, fields: fields)
    }

    // The unchecked initializer: the maker already stands on the layout.
    init(layout: Layout, fields: [Operation]) {
        assert(layout.fields.count == fields.count, "a struct literal has one field per place its layout names")

        self.layout = layout
        self.fields = fields
    }

    // MARK: - Public
    // MARK: - Private
}

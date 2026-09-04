//
//  RecordCode.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// A record literal as the run makes it: the layout the link made for it, and
// the code that fills each of its places. One field per place, checked where
// the pair is made, so the run reads the two together and never has to ask
// whether they still line up.
struct RecordCode: Sendable {
    // MARK: - Property
    let layout: Layout
    let fields: [Code]

    // MARK: - Initializer
    init(layout: Layout, fields: [Code]) {
        precondition(
            layout.fields.count == fields.count,
            "a record literal has one field per place its layout names"
        )

        self.layout = layout
        self.fields = fields
    }

    // MARK: - Public
    // MARK: - Private
}

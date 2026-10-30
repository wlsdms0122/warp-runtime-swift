//
//  Sent.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// One of a native procedure's declared sends, worked out: which row it
// reaches. What it hands comes in through the door at that row's slots.
//
// The row is a fact a build has and a run would otherwise look for. It is
// numbered by the sending document until the link resolves it, the way a call
// written in a body is.
struct Sent: Sendable, Equatable {
    // MARK: - Property
    let row: Int

    // MARK: - Initializer
    init(row: Int) {
        self.row = row
    }

    // MARK: - Public
    // The same send reaching another row, which is what relocating a document's
    // number to this link's row leaves.
    func reaching(_ row: Int) -> Sent {
        Sent(row: row)
    }

    // MARK: - Private
}

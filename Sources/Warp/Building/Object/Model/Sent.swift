//
//  Sent.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// One of a native procedure's declared sends, worked out: which row it reaches
// and how many arguments it hands over, from that row's first position.
//
// The row is an answer a build has and a run would otherwise look for. It is
// numbered by the sending document until the link answers it, the way a call
// written in a body is.
struct Sent: Sendable, Equatable {
    // MARK: - Property
    let row: Int

    // How many arguments the send hands over.
    let handing: Int

    // MARK: - Initializer
    init(row: Int, handing: Int) {
        self.row = row
        self.handing = handing
    }

    // MARK: - Public
    // The same send reaching another row, which is what relocating a document's
    // number to this link's row leaves.
    func reaching(_ row: Int) -> Sent {
        Sent(row: row, handing: handing)
    }

    // MARK: - Private
}

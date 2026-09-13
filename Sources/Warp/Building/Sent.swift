//
//  Sent.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// One of a native procedure's declared sends, worked out: which row it reaches
// and where each name it hands over stands among that row's parameters.
//
// Both are answers a build has and a run would otherwise look for. The row is
// numbered by the sending document until the link answers it, the way a call
// written in a body is. The places are the callee's parameter order, which no
// link moves, so they are settled once where the declaration is read and
// carried through as they are.
struct Sent: Sendable, Equatable {
    // MARK: - Property
    let row: Int

    // Where the handed names stand, in the order the procedure hands them.
    let offers: [Int]

    // MARK: - Initializer
    init(row: Int, offers: [Int]) {
        self.row = row
        self.offers = offers
    }

    // MARK: - Public
    // The same send reaching another row, which is what relocating a document's
    // number to this link's row leaves.
    func reaching(_ row: Int) -> Sent {
        Sent(row: row, offers: offers)
    }

    // MARK: - Private
}

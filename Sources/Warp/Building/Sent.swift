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
    init(row: Int, offers: [Int] = []) {
        self.row = row
        self.offers = offers
    }

    // MARK: - Public
    // The same send reaching another row, which is what relocating a document's
    // number to this link's row leaves.
    func reaching(_ row: Int) -> Sent {
        Sent(row: row, offers: offers)
    }

    // The values a run hands over, standing where the build worked out each one
    // goes. A procedure handing a different number of them than it declared it hands
    // is the one thing about a send a build cannot read, since how many a Swift
    // body builds is the body's, so it is said here.
    func handing(_ values: [Value], to selector: Name) throws -> [(position: Int, value: Value)] {
        guard values.count == offers.count else {
            throw ExecutionError(
                "'\(selector)' is handed \(values.count) here, and the procedure sending"
                    + " it declares it hands \(offers.count)"
            )
        }

        return zip(offers, values).map { position, value in (position: position, value: value) }
    }

    // MARK: - Private
}

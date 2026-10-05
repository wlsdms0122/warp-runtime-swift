//
//  Asking.swift
//  Warp
//
//  Created by JSilver on 10/5/26.
//

import Foundation

// The memberships already being asked of one reading or one value. One met
// again is the same question come back, which proves nothing.
struct Asking: Sendable {
    // MARK: - Property
    static let nothing = Asking(earlier: [], latest: nil)

    // The latest is held apart from the ones asked before it, so asking one
    // membership more than nothing builds no list.
    private let earlier: [Int]
    private let latest: Int?

    // MARK: - Initializer
    private init(earlier: [Int], latest: Int?) {
        self.earlier = earlier
        self.latest = latest
    }

    // MARK: - Public
    func contains(_ row: Int) -> Bool {
        latest == row || earlier.contains(row)
    }

    // The same, with one more membership asked.
    func adding(_ row: Int) -> Asking {
        Asking(earlier: latest.map { latest in earlier + [latest] } ?? earlier, latest: row)
    }

    // MARK: - Private
}
